import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:record/record.dart';
import 'package:cross_file/cross_file.dart';

import 'package:productivity/dataservice/wav.dart';
import 'package:productivity/dataservice/api_client.dart';

/// Nimmt Audio über das Mikrofon auf und schickt es an den /transcribe-Endpunkt.
///
/// Plattformübergreifend: native (Android/iOS/Windows) nimmt in eine Datei auf,
/// Web liefert eine Blob-URL. In beiden Fällen liest XFile die Bytes korrekt.
class TranscriptionService {
  TranscriptionService._();

  static final AudioRecorder _recorder = AudioRecorder();
  static const String _path = '/transcribe';

  // ── Die laufende Aufnahme, nativ ────────────────────────────────────
  // Nativ laeuft die Aufnahme seit dem Pegel-Problem ueber `startStream`:
  // die Abtastwerte kommen stueckweise hierher, statt dass das Paket sie
  // in eine Datei schreibt. Der Grund steht bei [pegel].

  static StreamSubscription<Uint8List>? _rohAbo;

  /// Wie eine Aufnahme auf fremden Ton reagiert: gar nicht.
  ///
  /// **Das war der Fehler hinter „Hey Jarvis -- und dann nichts".** Die
  /// Vorgabe von `record` ist [AudioInterruptionMode.pause]: beim Start
  /// fordert der Rekorder den Audio-Fokus an, und verliert er ihn, haelt
  /// er die Aufnahme an -- still, ohne Fehler, der Strom bleibt offen.
  /// Mit `pause` (anders als `pauseResume`) auch fuer immer.
  ///
  /// Den Fokus nimmt ihm ausgerechnet das Bestaetigungs-Pling: es startet
  /// unmittelbar NACH der Aufnahme, `audioplayers` fordert fuer jeden Ton
  /// Fokus an, und der Rekorder pausiert. Bis dahin hat er genau einmal
  /// gelesen -- das eine Stueck von 2560 Bytes (80 ms), das auf dem Tablet
  /// reproduzierbar ankam. Danach keine Pegel, keine Stille-Erkennung,
  /// nur die Notbremse, und Whisper bekam 80 ms. Beim Mikrofon-Knopf gibt
  /// es kein Pling; deshalb lief der.
  ///
  /// Dasselbe traf den Weckwort-Rekorder, sobald ein Timer klingelte oder
  /// Jarvis sprach: pausiert, und Jarvis war taub, bis jemand die
  /// Kuechenansicht neu oeffnete.
  ///
  /// Ein Mikrofon hat mit dem Audio-Fokus nichts zu schaffen -- der
  /// regelt, wer SPIELT. Zuhoeren darf man auch, waehrend etwas klingt;
  /// dass das Pling mit aufgenommen wird, faengt die Blindzeit im
  /// Sprach-Ablauf ab. Nebenbei haelt eine Aufnahme so nicht mehr die
  /// Musik anderer Apps an.
  static const AudioInterruptionMode aufnahmeOhneFokus =
      AudioInterruptionMode.none;

  /// Nur zur Untersuchung: wie viele Stuecke kamen, wie viele Bytes.
  static int _stuecke = 0;
  static final BytesBuilder _puffer = BytesBuilder();
  static StreamController<Amplitude>? _pegelCtrl;

  /// Lautstaerke eines Stuecks Abtastwerte, in dBFS.
  ///
  /// Effektivwert ueber die 16-Bit-Werte, nicht der Spitzenwert: ein
  /// einzelnes Knacken hebt den Spitzenwert auf Vollausschlag, und die
  /// Stille-Erkennung haette daraufhin einen Satz gehoert, wo eine Tuer
  /// zufiel.
  @visibleForTesting
  static double pegelAus(Uint8List stueck) {
    // ByteData statt `buffer.asInt16List`: die Stuecke aus dem Strom sind
    // Ausschnitte eines groesseren Puffers und beginnen an beliebiger
    // Byte-Position. `asInt16List` verlangt dort eine GERADE Position und
    // wirft sonst -- auf dem Geraet kam Position 5, und die Aufnahme
    // stuerzte bei jedem Stueck ab. `getInt16` kennt diese Einschraenkung
    // nicht.
    final sicht = ByteData.view(
        stueck.buffer, stueck.offsetInBytes, stueck.lengthInBytes);
    final anzahl = sicht.lengthInBytes ~/ 2;
    if (anzahl == 0) return -160.0;

    var summe = 0.0;
    for (var i = 0; i < anzahl; i++) {
      final w = sicht.getInt16(i * 2, Endian.little);
      summe += w * w;
    }
    final effektiv = math.sqrt(summe / anzahl);
    if (effektiv <= 0) return -160.0;
    // 32768 ist Vollausschlag bei 16 Bit. Untergrenze -160, damit aus
    // echter Stille kein negativ Unendlich wird.
    final db = 20 * (math.log(effektiv / 32768.0) / math.ln10);
    return db.isFinite ? (db < -160.0 ? -160.0 : db) : -160.0;
  }

  static Future<bool> hasPermission() => _recorder.hasPermission();

  static Future<bool> isRecording() => _recorder.isRecording();

  /// Lautstärkeverlauf der laufenden Aufnahme, in dBFS (0 = Vollausschlag,
  /// Stille liegt weit im Negativen). Damit erkennt der Sprach-Ablauf, wann
  /// der Satz zu Ende ist — beim Zurufen tippt niemand auf „Stopp".
  ///
  /// **Selbst gerechnet, nicht vom Paket geholt.** `getAmplitude()` liefert
  /// auf dem Küchen-Tablet (Galaxy Tab A8, `record_android` 1.5.2) eine
  /// **Konstante**: fünfundzwanzig Messungen hintereinander exakt derselbe
  /// Wert, `current` wie `max`. Zwischen zwei Aufnahmen ändert er sich —
  /// laut beim Schreien, leise beim Sprechen — aber **innerhalb** einer
  /// Aufnahme steht er still.
  ///
  /// Damit kann die Stille-Erkennung nicht arbeiten: entweder gilt
  /// durchgehend „spricht" und die Aufnahme läuft bis zur Notbremse, oder
  /// durchgehend „still" und sie endet mit „Nichts gehört". Etwas
  /// dazwischen gibt es nicht. Beides haben wir auf dem Gerät gesehen.
  ///
  /// Der Ausweg führt an dem Feld vorbei: `startStream` liefert die
  /// Abtastwerte selbst, und aus denen ist der Effektivwert eine
  /// Schulrechnung (siehe [pegelAus]). Nebenbei fällt damit das Schreiben
  /// in eine Datei weg — die WAV-Datei baut [Wav.ausPcm16] am Ende aus
  /// demselben Puffer.
  ///
  /// Der früher hier notierte Einwand gegen `pcm16bits` gilt weiterhin,
  /// trifft aber nicht mehr zu: er betraf die **Dateiendung**, aus der
  /// iOS das Containerformat ableitet. Ohne Datei gibt es keine Endung.
  static Stream<Amplitude> pegel(
      [Duration intervall = const Duration(milliseconds: 200)]) {
    // Das Intervall bestimmt jetzt das Aufnahmegerät über die Größe der
    // Stücke; der Parameter bleibt für die Aufrufstelle stehen.
    return _pegelCtrl?.stream ?? const Stream<Amplitude>.empty();
  }

  /// Die Abtastwerte der letzten Aufnahme — roh, 16 bit, 16 kHz, ein Kanal.
  ///
  /// Die Stimmerkennung braucht sie, und zwar **dieselben**, die auch zur
  /// Transkription gehen: das Mikrofon gehört immer nur einem, zweimal
  /// aufnehmen geht also nicht. Auf Web bleibt das null — dort wird in
  /// Opus aufgenommen und nicht erkannt.
  static Uint8List? letzteAufnahme;

  /// Startet die Aufnahme. Wirft, wenn kein Mikrofon-Zugriff besteht.
  ///
  /// Nativ wird seit der Stimmerkennung als **WAV** aufgenommen statt in
  /// AAC. Der Grund steht in `wav.dart`: AAC lässt sich in Dart nicht ohne
  /// weiteres aufmachen, und das Modell will Abtastwerte. Aus einer
  /// WAV-Datei sind sie herauszuholen, ohne etwas zu dekodieren — und
  /// Whisper liest WAV ohne Umstand.
  ///
  /// **Warum WAV und nicht `pcm16bits`:** beide schreiben dieselben
  /// Abtastwerte, aber `AVAudioRecorder` auf iOS leitet das
  /// Containerformat aus der **Dateiendung** ab. Eine Endung `.pcm` kennt
  /// es nicht. WAV ist der Weg, den die Plattform selbst vorsieht.
  ///
  /// Der Preis ist die Größe: 32 kB je Sekunde statt gut 2 kB. Bei
  /// fünfzehn Sekunden über das eigene WLAN fällt das nicht ins Gewicht.
  static Future<void> start() async {
    letzteAufnahme = null;
    await _stromAufraeumen();

    if (kIsWeb) {
      // Web kann keine Abtastwerte streamen und auch kein WAV in eine
      // Datei schreiben -> Opus/WebM in eine Blob-URL, wie bisher. Dort
      // gibt es folglich auch keine Pegel und keine Stille-Erkennung;
      // die Kuechenansicht laeuft ohnehin nicht im Browser.
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.opus,
          sampleRate: Wav.rate,
          numChannels: 1,
          audioInterruption: aufnahmeOhneFokus,
        ),
        path: '',
      );
      return;
    }

    _puffer.clear();
    _stuecke = 0;
    _pegelCtrl = StreamController<Amplitude>.broadcast();

    final strom = await _recorder.startStream(
      const RecordConfig(
        // Rohe Abtastwerte statt einer WAV-Datei. Die Datei baut
        // [Wav.ausPcm16] am Ende selbst -- siehe [pegel].
        encoder: AudioEncoder.pcm16bits,
        // Beide Modelle -- Weckwort und Sprecher -- erwarten genau das.
        // Eine andere Rate liefert bei beiden Unsinn, keinen Fehler.
        sampleRate: Wav.rate,
        numChannels: 1,
        // Siehe [aufnahmeOhneFokus]. DAS war der Grund fuer das eine
        // Stueck von 80 ms nach „Hey Jarvis".
        audioInterruption: aufnahmeOhneFokus,
      ),
    );

    debugPrint('[Jarvis] startStream steht, warte auf Stuecke');

    _rohAbo = strom.listen(
      (stueck) {
        _stuecke++;
        if (_stuecke <= 3) {
          debugPrint('[Jarvis] Stueck $_stuecke: ${stueck.lengthInBytes} Bytes, '
              'Versatz ${stueck.offsetInBytes}');
        }
        _puffer.add(stueck);
        final db = pegelAus(stueck);
        if (!(_pegelCtrl?.isClosed ?? true)) {
          _pegelCtrl!.add(Amplitude(current: db, max: db));
        }
      },
      // Reisst der Strom, ist die Aufnahme zu Ende. Der Sprach-Ablauf
      // merkt es an der ausbleibenden Stille-Erkennung und faellt auf
      // seine Notbremse zurueck.
      onError: (e) => debugPrint('[Jarvis] Strom-Fehler: $e'),
      onDone: () => debugPrint('[Jarvis] Strom zu Ende nach $_stuecke Stuecken'),
      cancelOnError: false,
    );
  }

  /// Abo und Pegelkanal der letzten Aufnahme schliessen.
  static Future<void> _stromAufraeumen() async {
    await _rohAbo?.cancel();
    _rohAbo = null;
    final ctrl = _pegelCtrl;
    _pegelCtrl = null;
    await ctrl?.close();
  }

  /// Stoppt die Aufnahme und gibt die gesammelten Abtastwerte zurueck.
  ///
  /// Null auf Web und wenn nichts lief.
  static Future<Uint8List?> _stoppUndPcm() async {
    debugPrint('[Jarvis] Stopp: $_stuecke Stuecke, '
        '${_puffer.length} Bytes gesammelt');
    await _recorder.stop();
    await _stromAufraeumen();
    final pcm = _puffer.takeBytes();
    return pcm.isEmpty ? null : pcm;
  }

  /// Stoppt die Aufnahme und gibt nur die Abtastwerte zurück.
  ///
  /// Für das Einlernen einer Stimme: dort wird nichts transkribiert, der
  /// Satz ist gleichgültig — es zählt allein der Klang. Ihn trotzdem durch
  /// Whisper zu schicken wäre Rechenzeit für nichts und ein Text, den
  /// niemand liest.
  ///
  /// Null auf Web (dort wird in Opus aufgenommen) und wenn nichts lief.
  static Future<Uint8List?> stopNurAudio() async {
    if (kIsWeb) {
      await _recorder.stop();
      return null;
    }
    // Die Abtastwerte liegen schon roh vor -- kein Umweg mehr ueber eine
    // Datei und `Wav.pcmAus`.
    letzteAufnahme = await _stoppUndPcm();
    return letzteAufnahme;
  }

  /// Stoppt die Aufnahme, lädt sie hoch und liefert den Text.
  ///
  /// Der Endpunkt streamt NDJSON: pro Whisper-Segment {"type":"segment",...},
  /// am Ende {"type":"done", text}. [onSegment] wird – falls gesetzt – für jedes
  /// Segment aufgerufen, sodass der Text in der App nach und nach erscheint.
  /// Rückgabe: der vollständige erkannte Text.
  ///
  /// [model] wählt das Whisper-Modell und damit zwischen Genauigkeit und
  /// Tempo. Ein Diktat in die Notizen lässt es leer (Servervorgabe, genau);
  /// ein zugerufener Sprachbefehl übergibt ein kleines Modell wie 'small' und
  /// spart damit den Großteil der Wartezeit.
  static Future<String> stopAndTranscribe({
    String? language,
    String? model,
    void Function(String segment)? onSegment,
  }) async {
    final Uint8List bytes;
    final String filename;

    if (kIsWeb) {
      final result = await _recorder.stop();
      if (result == null) throw Exception('Keine Aufnahme vorhanden.');
      bytes = await XFile(result).readAsBytes();
      filename = 'audio.webm';
    } else {
      // Aus den gesammelten Abtastwerten wird hier die WAV-Datei --
      // dieselben Werte, die auch die Stimmerkennung bekommt. Zweimal
      // aufnehmen geht nicht, das Mikrofon gehoert immer nur einem.
      final pcm = await _stoppUndPcm();
      if (pcm == null) throw Exception('Keine Aufnahme vorhanden.');
      letzteAufnahme = pcm;
      bytes = Wav.ausPcm16(pcm);
      filename = 'audio.wav';
    }

    if (bytes.isEmpty) {
      throw Exception('Leere Aufnahme.');
    }

    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    final response = await ApiClient.dio.post(
      _path,
      data: form,
      queryParameters: {
        'language': ?language,
        'model': ?model,
      },
      options: Options(responseType: ResponseType.stream),
    );

    final lines =
        const LineSplitter().bind(utf8.decoder.bind(response.data.stream));
    final buffer = StringBuffer();
    String full = '';
    String? error;

    await lines.forEach((line) {
      if (line.trim().isEmpty) return;
      Map<String, dynamic> json;
      try {
        json = jsonDecode(line) as Map<String, dynamic>;
      } catch (_) {
        return;
      }
      switch (json['type']) {
        case 'segment':
          final t = (json['text'] ?? '').toString();
          if (t.isNotEmpty) {
            buffer.write(t);
            onSegment?.call(t);
          }
          break;
        case 'done':
          full = (json['text'] ?? '').toString();
          break;
        case 'error':
          error = (json['detail'] ?? 'Transkription fehlgeschlagen').toString();
          break;
      }
    });

    if (error != null) throw Exception(error);
    return full.isNotEmpty ? full : buffer.toString().trim();
  }

  /// Bricht eine laufende Aufnahme ab (verwirft sie).
  static Future<void> cancel() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    await _stromAufraeumen();
    _puffer.clear();
  }
}

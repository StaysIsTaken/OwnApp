import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'package:productivity/dataservice/transcription_service.dart';

/// Lauscht dauerhaft auf „Jarvis" und meldet sich, wenn es fällt.
///
/// Warum sherpa-onnx und nicht Whisper: Whisper braucht einen fertigen
/// Audioschnipsel und Sekunden Rechenzeit. Ein Weckworterkenner prüft laufend
/// einen Strom und kostet dabei wenige Prozent eines Kerns. Zwei
/// verschiedene Aufgaben, auch wenn beide „Sprache erkennen" heißen.
///
/// Warum nicht Porcupine: dessen AccessKey gibt es nur über eine Anmeldung,
/// die eine Firmen-Adresse verlangt. sherpa-onnx ist Apache-2.0, läuft
/// vollständig auf dem Gerät und braucht kein Konto. Der Preis: es bringt
/// keine Audioaufnahme mit — den Strom liefert hier [_rekorder].
///
/// **Das Mikrofon gehört immer nur einem.** Solange gelauscht wird, hält
/// dieser Dienst den Audiostrom; wer danach aufnehmen will, muss vorher
/// [anhalten] rufen und [fortsetzen] in ein `finally` legen. Sonst ist Jarvis
/// nach dem ersten Fehler für immer taub.
class WakewordService {
  WakewordService._();

  /// Das Modell erwartet 16 kHz, einkanalig. Andere Raten liefern Unsinn.
  static const int _rate = 16000;

  /// Die Modelldateien im Asset-Bündel. Sie werden einmalig in den
  /// Dokumentenordner kopiert: die ONNX-Laufzeit öffnet echte Dateien und
  /// kann mit einem Flutter-Asset nichts anfangen.
  static const List<String> _dateien = [
    'encoder.int8.onnx',
    'decoder.int8.onnx',
    'joiner.int8.onnx',
    'tokens.txt',
    'keywords.txt',
  ];

  static sherpa.KeywordSpotter? _spotter;
  static sherpa.OnlineStream? _strom;
  static AudioRecorder? _rekorder;
  static StreamSubscription<Uint8List>? _abo;
  static bool _laeuft = false;
  static bool _gebunden = false;

  // Beim Starten hinterlegt, damit [fortsetzen] den Strom ohne den Aufrufer
  // wieder anwerfen kann.
  static VoidCallback? _beiWakeword;
  static void Function(String)? _beiFehler;

  /// Ob gerade gelauscht wird.
  static bool get laeuft => _laeuft;

  /// Ob ein Erkenner geladen ist.
  static bool get bereit => _spotter != null;

  /// Kopiert ein Asset in den Dokumentenordner, falls es dort fehlt oder eine
  /// andere Größe hat (nach einem App-Update kann das Modell neu sein).
  static Future<String> _ausgepackt(String name) async {
    final ordner = await getApplicationSupportDirectory();
    final ziel = File('${ordner.path}/kws/$name');
    final daten = await rootBundle.load('assets/kws/$name');
    final bytes = daten.buffer.asUint8List(
        daten.offsetInBytes, daten.lengthInBytes);

    if (!await ziel.exists() || await ziel.length() != bytes.length) {
      await ziel.parent.create(recursive: true);
      await ziel.writeAsBytes(bytes, flush: true);
    }
    return ziel.path;
  }

  /// Lädt das Modell und beginnt zu lauschen.
  ///
  /// [beiWakeword] wird gerufen, sobald ein Schlüsselwort fällt.
  /// [schwelle] entspricht `keywordsThreshold`: kleiner heißt empfindlicher
  /// und damit mehr Fehlauslöser, größer heißt lauter rufen.
  static Future<void> starten({
    required VoidCallback beiWakeword,
    double schwelle = 0.25,
    void Function(String meldung)? beiFehler,
  }) async {
    _beiWakeword = beiWakeword;
    _beiFehler = beiFehler;

    if (_spotter != null) {
      await fortsetzen();
      return;
    }

    if (!_gebunden) {
      // Muss einmal je Isolate passieren, bevor irgendetwas erzeugt wird.
      sherpa.initBindings();
      _gebunden = true;
    }

    final pfade = <String, String>{};
    for (final n in _dateien) {
      pfade[n] = await _ausgepackt(n);
    }

    _spotter = sherpa.KeywordSpotter(sherpa.KeywordSpotterConfig(
      model: sherpa.OnlineModelConfig(
        transducer: sherpa.OnlineTransducerModelConfig(
          encoder: pfade['encoder.int8.onnx']!,
          decoder: pfade['decoder.int8.onnx']!,
          joiner: pfade['joiner.int8.onnx']!,
        ),
        tokens: pfade['tokens.txt']!,
        modelType: 'zipformer2',
        // Ein Kern genügt und lässt dem Rest des Tablets Luft. Das Modell hat
        // 3,3 Millionen Parameter; es geht hier nicht um Durchsatz.
        numThreads: 1,
        // debug lässt sherpa sonst bei jedem Start seine ganze Konfiguration
        // ins Log schreiben.
        debug: false,
      ),
      keywordsFile: pfade['keywords.txt']!,
      keywordsThreshold: schwelle,
    ));

    _strom = _spotter!.createStream();
    await fortsetzen();
  }

  static void _verarbeite(Uint8List bytes, VoidCallback beiWakeword) {
    final spotter = _spotter;
    final strom = _strom;
    if (spotter == null || strom == null) return;

    strom.acceptWaveform(samples: _alsFloat(bytes), sampleRate: _rate);
    while (spotter.isReady(strom)) {
      spotter.decode(strom);
    }
    if (spotter.getResult(strom).keyword.isNotEmpty) {
      // Zurücksetzen, sonst bliebe der Treffer stehen und löste beim nächsten
      // Häppchen sofort wieder aus.
      spotter.reset(strom);
      beiWakeword();
    }
  }

  /// PCM 16 Bit, vorzeichenbehaftet, Little Endian -> Float im Bereich -1..1.
  /// Das erwartet sherpa; 32768 ist der Vollausschlag.
  @visibleForTesting
  static Float32List alsFloatFuerTest(Uint8List bytes) => _alsFloat(bytes);

  static Float32List _alsFloat(Uint8List bytes) {
    final anzahl = bytes.length ~/ 2;
    final werte = Float32List(anzahl);
    final sicht = ByteData.sublistView(bytes);
    for (var i = 0; i < anzahl; i++) {
      werte[i] = sicht.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return werte;
  }

  /// Hält das Lauschen an und gibt das Mikrofon frei. Erkenner und Modell
  /// bleiben im Speicher — sie neu zu laden dauert spürbar länger.
  ///
  /// **`stop()` allein genügt nicht, der Rekorder muss weg.**
  /// `AudioRecorder` hält seine native Aufnahmesitzung, bis er freigegeben
  /// wird. Hier und in `TranscriptionService` gibt es je einen — zwei
  /// Rekorder auf einem Mikrofon, und das Mikrofon gehört immer nur einem.
  ///
  /// Hier stand einmal, das sei der Grund, warum die Aufnahme nach dem
  /// Weckwort nur EIN Stück von 80 ms bekam. Das stimmte nicht — das
  /// Freigeben änderte daran nichts. Der Grund war der Audio-Fokus, siehe
  /// `TranscriptionService.aufnahmeOhneFokus`. Freigeben bleibt trotzdem
  /// richtig.
  ///
  /// Freigeben kostet hier nichts: [fortsetzen] legt ihn ohnehin neu an,
  /// und teuer ist allein das Modell — das bleibt.
  static Future<void> anhalten() async {
    if (!_laeuft) return;
    _laeuft = false;
    await _abo?.cancel();
    _abo = null;
    try {
      await _rekorder?.stop();
      await _rekorder?.dispose();
    } catch (_) {
      // Schon gestoppt ist kein Fehler.
    }
    _rekorder = null;
  }

  /// Nimmt das Mikrofon wieder in Beschlag und lauscht weiter.
  ///
  /// Startet den Audiostrom jedes Mal neu. Ein bloßes Flag zu setzen würde
  /// nicht genügen: `anhalten` beendet den Rekorder, und ein beendeter
  /// Rekorder liefert nichts mehr.
  static Future<void> fortsetzen() async {
    if (_laeuft || _spotter == null) return;
    final rufe = _beiWakeword;
    if (rufe == null) return;

    _rekorder ??= AudioRecorder();
    if (!await _rekorder!.hasPermission()) {
      throw StateError('Kein Mikrofon-Zugriff erlaubt.');
    }

    final strom = await _rekorder!.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _rate,
      numChannels: 1,
      // Ohne das haelt ein klingelnder Timer oder die eigene Stimme das
      // Lauschen an -- still und fuer immer. Siehe
      // `TranscriptionService.aufnahmeOhneFokus`.
      audioInterruption: TranscriptionService.aufnahmeOhneFokus,
    ));
    _abo = strom.listen(
      (bytes) => _verarbeite(bytes, rufe),
      onError: (Object e) {
        _laeuft = false;
        _beiFehler?.call('Weckwort-Erkennung abgebrochen: $e');
      },
    );
    _laeuft = true;
  }

  /// Gibt alles frei. Beim Verlassen der Küchenansicht — ein Gerät, das
  /// jemand aus dem Raum trägt, soll nicht mithören.
  static Future<void> beenden() async {
    await anhalten();
    _strom?.free();
    _strom = null;
    _spotter?.free();
    _spotter = null;
    await _rekorder?.dispose();
    _rekorder = null;
  }

  /// Übersetzt die Ausnahmen in etwas, das man einem Menschen zeigen kann.
  static String erklaere(Object e) => switch (e) {
        StateError() => e.message,
        FileSystemException() =>
          'Das Weckwort-Modell liess sich nicht auspacken.',
        _ => 'Weckwort nicht gestartet: $e',
      };
}

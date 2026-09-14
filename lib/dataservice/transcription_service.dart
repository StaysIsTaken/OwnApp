import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:record/record.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';

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

  static Future<bool> hasPermission() => _recorder.hasPermission();

  static Future<bool> isRecording() => _recorder.isRecording();

  /// Lautstärkeverlauf der laufenden Aufnahme, in dBFS (0 = Vollausschlag,
  /// Stille liegt weit im Negativen). Damit erkennt der Sprach-Ablauf, wann
  /// der Satz zu Ende ist — beim Zurufen tippt niemand auf „Stopp".
  static Stream<Amplitude> pegel(
          [Duration intervall = const Duration(milliseconds: 200)]) =>
      _recorder.onAmplitudeChanged(intervall);

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
    // Web kann kein WAV in eine Datei schreiben -> Opus/WebM wie bisher.
    final encoder = kIsWeb ? AudioEncoder.opus : AudioEncoder.wav;

    String path = '';
    if (!kIsWeb) {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      path = '${dir.path}/rec_$stamp.wav';
    }
    letzteAufnahme = null;
    await _recorder.start(
      RecordConfig(
        encoder: encoder,
        // Beide Modelle -- Weckwort und Sprecher -- erwarten genau das.
        // Eine andere Rate liefert bei beiden Unsinn, keinen Fehler.
        sampleRate: Wav.rate,
        numChannels: 1,
      ),
      path: path,
    );
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
    final result = await _recorder.stop();
    if (result == null || kIsWeb) return null;
    final datei = await XFile(result).readAsBytes();
    final pcm = Wav.pcmAus(datei);
    letzteAufnahme = pcm.isEmpty ? null : pcm;
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
    final result = await _recorder.stop();
    if (result == null) {
      throw Exception('Keine Aufnahme vorhanden.');
    }

    final roh = await XFile(result).readAsBytes();
    if (roh.isEmpty) {
      throw Exception('Leere Aufnahme.');
    }

    // Nativ liegt hier fertiges WAV: das geht unverändert zum Server, und
    // die Stimmerkennung hebt sich die Abtastwerte daraus ab. Auf Web
    // bleibt alles wie bisher.
    final Uint8List bytes = roh;
    final String filename;
    if (kIsWeb) {
      filename = 'audio.webm';
    } else {
      filename = 'audio.wav';
      final pcm = Wav.pcmAus(roh);
      letzteAufnahme = pcm.isEmpty ? null : pcm;
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
  }
}

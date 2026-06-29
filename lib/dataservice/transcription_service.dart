import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:record/record.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
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

  /// Startet die Aufnahme. Wirft, wenn kein Mikrofon-Zugriff besteht.
  static Future<void> start() async {
    // Web kann kein AAC -> Opus/WebM; native nutzt AAC (universell dekodierbar).
    final encoder = kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc;

    String path = '';
    if (!kIsWeb) {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      path = '${dir.path}/rec_$stamp.m4a';
    }
    await _recorder.start(RecordConfig(encoder: encoder), path: path);
  }

  /// Stoppt die Aufnahme, lädt sie hoch und liefert den Text.
  ///
  /// Der Endpunkt streamt NDJSON: pro Whisper-Segment {"type":"segment",...},
  /// am Ende {"type":"done", text}. [onSegment] wird – falls gesetzt – für jedes
  /// Segment aufgerufen, sodass der Text in der App nach und nach erscheint.
  /// Rückgabe: der vollständige erkannte Text.
  static Future<String> stopAndTranscribe({
    String? language,
    void Function(String segment)? onSegment,
  }) async {
    final result = await _recorder.stop();
    if (result == null) {
      throw Exception('Keine Aufnahme vorhanden.');
    }

    final bytes = await XFile(result).readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Leere Aufnahme.');
    }

    final filename = kIsWeb ? 'audio.webm' : 'audio.m4a';
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    final response = await ApiClient.dio.post(
      _path,
      data: form,
      queryParameters: language != null ? {'language': language} : null,
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

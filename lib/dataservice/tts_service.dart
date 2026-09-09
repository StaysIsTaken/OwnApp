import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Sprachausgabe über die Stimme des Betriebssystems.
///
/// Bewusst die System-TTS und kein Server-Dienst: sie antwortet ohne
/// Netzwerkweg und ohne Wartezeit. Sie klingt dafür etwas nüchtern — für
/// „Steht auf der Einkaufsliste" reicht das.
class TtsService {
  TtsService._();

  static final FlutterTts _tts = FlutterTts();
  static bool _eingerichtet = false;

  /// Ab welcher Länge eine Antwort gekürzt vorgelesen wird. Der volle Text
  /// steht auf dem Bildschirm; vorgelesen wird nur der Anfang. Ein Assistent,
  /// der einen Absatz herunterbetet, wird sonst schnell lästig.
  static const int _maxZeichen = 350;

  static Future<void> _einrichten() async {
    if (_eingerichtet) return;
    await _tts.setLanguage('de-DE');
    await _tts.setSpeechRate(0.55); // Die Vorgabe wirkt gedehnt.
    await _tts.setPitch(1.0);
    // Ohne das kehrt speak() sofort zurück. Der Aufrufer muss aber wissen,
    // wann das Reden vorbei ist – spätestens beim Wakeword, das erst danach
    // wieder lauschen darf.
    await _tts.awaitSpeakCompletion(true);
    _eingerichtet = true;
  }

  /// Liest [text] vor und kehrt zurück, wenn er zu Ende gesprochen ist.
  /// Fehler werden geschluckt: eine fehlende Stimme darf den Sprach-Ablauf
  /// nicht abbrechen, der Text steht ja trotzdem auf dem Schirm.
  static Future<void> sprich(String text) async {
    final t = kuerze(text);
    if (t.isEmpty) return;
    try {
      await _einrichten();
      await _tts.stop();
      await _tts.speak(t);
    } catch (e) {
      debugPrint('[TTS] Sprachausgabe fehlgeschlagen: $e');
    }
  }

  static Future<void> stopp() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Nichts zu stoppen ist kein Fehler.
    }
  }

  /// Kürzt auf [_maxZeichen], aber an einem Satzende — mitten im Wort
  /// abzubrechen klingt nach Defekt.
  static String kuerze(String text) {
    final t = text.trim();
    if (t.length <= _maxZeichen) return t;

    final anfang = t.substring(0, _maxZeichen);
    final schnitt = [
      anfang.lastIndexOf('. '),
      anfang.lastIndexOf('! '),
      anfang.lastIndexOf('? '),
      anfang.lastIndexOf('\n'),
    ].reduce((a, b) => a > b ? a : b);
    if (schnitt > _maxZeichen ~/ 3) return anfang.substring(0, schnitt + 1);

    final wort = anfang.lastIndexOf(' ');
    return wort > 0 ? '${anfang.substring(0, wort)} …' : anfang;
  }
}

import 'package:flutter/foundation.dart';
import 'package:porcupine_flutter/porcupine.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';

/// Lauscht dauerhaft auf „Jarvis" und meldet sich, wenn es fällt.
///
/// Warum Porcupine und nicht Whisper: Whisper braucht einen fertigen
/// Audioschnipsel und Sekunden Rechenzeit. Ein Wakeword-Erkenner prüft
/// laufend einen Strom und kostet dabei wenige Prozent eines Kerns. Das sind
/// zwei verschiedene Aufgaben, auch wenn beide „Sprache erkennen" heißen.
///
/// `JARVIS` ist ein eingebautes Schlüsselwort — es braucht keine eigene
/// `.ppn`-Datei und keine Nachtrainierung. Dass das Modell englisch ist,
/// stört nicht: Wecken und Verstehen sind getrennt. Jarvis weckt, danach
/// transkribiert Whisper ganz normal Deutsch.
///
/// **Das Mikrofon gehört immer nur einem.** Porcupine hält den Audiostrom,
/// solange es läuft — wer danach aufnehmen will, muss es vorher anhalten.
/// Genau dafür sind [anhalten] und [fortsetzen] da, und der Aufrufer muss
/// [fortsetzen] in ein `finally` legen. Sonst ist Jarvis nach dem ersten
/// Fehler für immer taub.
class WakewordService {
  WakewordService._();

  /// Niedriger als die Vorgabe 0.5. Ein Fehlauslöser mitten im Abendessen
  /// nervt mehr, als einmal lauter rufen zu müssen — und der Fernseher redet
  /// in einer Küche mehr als jeder Mensch.
  static const double _empfindlichkeit = 0.4;

  static PorcupineManager? _manager;
  static bool _laeuft = false;

  /// Ob gerade gelauscht wird.
  static bool get laeuft => _laeuft;

  /// Ob überhaupt ein Erkenner geladen ist.
  static bool get bereit => _manager != null;

  /// Lädt Porcupine und beginnt zu lauschen.
  ///
  /// [beiWakeword] wird gerufen, sobald „Jarvis" fällt. Wirft eine
  /// [PorcupineException] mit einer verständlichen Meldung, wenn der
  /// AccessKey fehlt, abgelaufen ist oder das Kontingent erschöpft ist —
  /// der Aufrufer soll das anzeigen können, statt still nicht zu lauschen.
  static Future<void> starten({
    required String accessKey,
    required VoidCallback beiWakeword,
    void Function(String meldung)? beiFehler,
  }) async {
    if (_manager != null) return;
    if (accessKey.trim().isEmpty) {
      throw ArgumentError('Kein Picovoice-AccessKey hinterlegt.');
    }

    _manager = await PorcupineManager.fromBuiltInKeywords(
      accessKey.trim(),
      [BuiltInKeyword.JARVIS],
      (_) => beiWakeword(),
      sensitivities: [_empfindlichkeit],
      errorCallback: (e) {
        // Laufzeitfehler kommen asynchron und ohne Bezug zu einem Aufruf.
        // Sie bedeuten in aller Regel, dass nicht mehr gelauscht wird.
        _laeuft = false;
        beiFehler?.call(erklaere(e));
      },
    );
    await _manager!.start();
    _laeuft = true;
  }

  /// Hält das Lauschen an und gibt das Mikrofon frei. Der geladene Erkenner
  /// bleibt im Speicher — ihn neu zu laden dauert spürbar länger als ein
  /// [fortsetzen].
  static Future<void> anhalten() async {
    if (_manager == null || !_laeuft) return;
    await _manager!.stop();
    _laeuft = false;
  }

  static Future<void> fortsetzen() async {
    if (_manager == null || _laeuft) return;
    await _manager!.start();
    _laeuft = true;
  }

  /// Gibt den Erkenner ganz frei. Beim Verlassen der Küchenansicht — ein
  /// Telefon in der Hosentasche soll nicht mithören.
  static Future<void> beenden() async {
    final m = _manager;
    _manager = null;
    _laeuft = false;
    if (m == null) return;
    try {
      await m.stop();
    } catch (_) {
      // Schon gestoppt ist kein Fehler.
    }
    await m.delete();
  }

  /// Übersetzt die Ausnahmen in etwas, das man einem Menschen zeigen kann.
  /// Porcupines eigene Meldungen sind englisch und nennen Ursachen, die man
  /// ohne die Picovoice-Konsole nicht einordnen kann.
  static String erklaere(Object e) => switch (e) {
        PorcupineActivationLimitException() =>
          'Das Gerätekontingent des Picovoice-Kontos ist erschöpft.',
        PorcupineActivationRefusedException() ||
        PorcupineActivationException() =>
          'Der Picovoice-AccessKey wurde abgelehnt.',
        PorcupineActivationThrottledException() =>
          'Zu viele Aktivierungsversuche. Später nochmal.',
        PorcupineKeyException() =>
          'Der Picovoice-AccessKey ist ungültig.',
        ArgumentError() => 'Kein Picovoice-AccessKey hinterlegt.',
        _ => 'Wakeword nicht gestartet: $e',
      };
}

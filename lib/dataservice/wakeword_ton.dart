import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Das kurze Pling, mit dem Jarvis bestätigt, dass er wach ist.
///
/// Klingt nach Kleinigkeit, ist aber die halbe gefühlte Qualität: ohne
/// Rückmeldung ruft man ein zweites Mal, weil man nicht weiß, ob das Gerät
/// zugehört hat. Zwei aufsteigende Töne, zusammen 180 ms — aufsteigend, weil
/// das nach „bereit" klingt und nicht nach Fehler.
///
/// Getrennt von [TimerTon], obwohl beide Töne abspielen: zwei Abspieler
/// heißt, dass ein klingelnder Timer das Pling nicht abschneidet.
class WakewordTon {
  WakewordTon._();

  static const String datei = 'sounds/wakeword.wav';

  static AudioPlayer? _spieler;

  /// Für Tests: nichts abspielen, nur mitzählen.
  @visibleForTesting
  static int gespielt = 0;

  @visibleForTesting
  static bool stumm = false;

  static Future<void> spielen() async {
    gespielt++;
    if (stumm) return;
    try {
      final s = _spieler ??= AudioPlayer();
      await s.stop();
      await s.play(AssetSource(datei));
    } catch (e) {
      // Kein Ton ist kein Grund, den Zuruf fallenzulassen.
      debugPrint('Wakeword-Ton konnte nicht abgespielt werden: $e');
    }
  }
}

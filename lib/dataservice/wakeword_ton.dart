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

  static final AudioContext _ohneFokus = AudioContext(
    android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
  );

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
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        // Kein Audio-Fokus für 180 ms Pling. Die Vorgabe `gain` nähme ihn
        // der Aufnahme weg, die im selben Moment startet — und die hielt
        // darauf an (siehe `TranscriptionService.aufnahmeOhneFokus`).
        // Außerdem stoppte sie die Musik anderer Apps, statt kurz
        // darüberzuklingen. Nur Android: auf iOS setzte derselbe Aufruf
        // die Audio-Sitzung auf reines Abspielen und das Mikrofon still.
        await s.setAudioContext(_ohneFokus);
      }
      await s.stop();
      await s.play(AssetSource(datei));
    } catch (e) {
      // Kein Ton ist kein Grund, den Zuruf fallenzulassen.
      debugPrint('Wakeword-Ton konnte nicht abgespielt werden: $e');
    }
  }
}

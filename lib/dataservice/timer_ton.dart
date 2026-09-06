import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Der Ton, mit dem sich der Küchen-Timer meldet.
///
/// Eigene Klasse statt eines Aufrufs mitten im Widget, aus zwei Gründen:
/// der Abspieler soll einer bleiben (jeder neue hält eine Audio-Sitzung
/// offen), und ein Timer, dessen Ton nicht kommt, soll trotzdem ablaufen —
/// die rote Anzeige ist die eigentliche Meldung, der Ton die Zugabe.
///
/// Im Web darf eine Seite erst Ton abspielen, nachdem jemand sie berührt
/// hat. Auf dem Küchen-Tablet ist das kein Problem: den Timer stellt man
/// von Hand, und damit ist die Bedingung erfüllt. Passiert es doch, bleibt
/// es still statt zu werfen.
class TimerTon {
  TimerTon._();

  static const String datei = 'sounds/timer_alarm.mp3';

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
      // Von vorn, auch wenn der vorige Lauf noch klingt.
      await s.stop();
      await s.play(AssetSource(datei));
    } catch (e) {
      // Kein Ton ist kein Grund, den Timer scheitern zu lassen.
      debugPrint('Timer-Ton konnte nicht abgespielt werden: $e');
    }
  }

  /// Beim Verlassen der Kachel: sonst klingelt es weiter, während man
  /// längst etwas anderes ansieht.
  static Future<void> aufhoeren() async {
    try {
      await _spieler?.stop();
    } catch (_) {
      // Schon gestoppt oder nie gestartet.
    }
  }
}

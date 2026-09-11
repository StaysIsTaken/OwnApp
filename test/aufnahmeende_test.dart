// Wann eine Sprachaufnahme endet.
//
// Diese Rechnung sass frueher mitten im Pegelstrom des Mikrofons und war
// damit nur auf einem Geraet zu pruefen. Genau dort steckte ein Fehler, der
// im Alltag so aussah: "Hey Jarvis" wird erkannt, danach passiert nichts
// mehr ausser "Nichts verstanden". Ursache war, dass ein einzelner
// Pegelausschlag -- das Bestaetigungs-Pling -- schon als Sprache zaehlte und
// die Stille-Uhr startete. Wer danach kurz ueberlegte, dessen Aufnahme war
// vorbei, bevor er das erste Wort gesagt hatte.
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/provider/sprach_provider.dart';

Aufnahmeschritt schritt({
  required int seitStartMs,
  required int seitStimmeMs,
  bool hatGesprochen = true,
}) =>
    SprachProvider.entscheide(
      seitStart: Duration(milliseconds: seitStartMs),
      seitLetzterStimme: Duration(milliseconds: seitStimmeMs),
      hatGesprochen: hatGesprochen,
    );

void main() {
  group('Blindzeit am Anfang', () {
    test('in den ersten 600 ms passiert nichts', () {
      // Dort faellt das Pling hinein. Selbst eine lange Stille darf die
      // Aufnahme hier noch nicht beenden.
      expect(schritt(seitStartMs: 100, seitStimmeMs: 100),
          Aufnahmeschritt.weiter);
      expect(schritt(seitStartMs: 599, seitStimmeMs: 599, hatGesprochen: false),
          Aufnahmeschritt.weiter);
    });
  });

  group('Niemand sagt etwas', () {
    test('bis zum Vorlauf wird gewartet', () {
      expect(schritt(seitStartMs: 5000, seitStimmeMs: 5000, hatGesprochen: false),
          Aufnahmeschritt.weiter);
    });

    test('danach wird verworfen statt hochgeladen', () {
      expect(schritt(seitStartMs: 6500, seitStimmeMs: 6500, hatGesprochen: false),
          Aufnahmeschritt.nichtsGehoert);
    });
  });

  group('Der Fehler, der im Alltag auftrat', () {
    test('ein kurzer Ton am Anfang beendet die Aufnahme NICHT', () {
      // Das ist der Regressionstest. Gesprochen wurde bei 700 ms (das Pling),
      // seitdem ist es still. Frueher endete die Aufnahme hier nach 1,2 s
      // Stille -- also bei rund 1,9 s, bevor der Nutzer angefangen hatte.
      expect(schritt(seitStartMs: 1900, seitStimmeMs: 1200),
          Aufnahmeschritt.weiter);
      expect(schritt(seitStartMs: 2400, seitStimmeMs: 1700),
          Aufnahmeschritt.weiter);
    });

    test('vor der Mindestdauer endet nie etwas', () {
      // Selbst eine sehr lange Stille nicht.
      expect(schritt(seitStartMs: 2499, seitStimmeMs: 2499),
          Aufnahmeschritt.weiter);
    });
  });

  group('Normales Sprechen', () {
    test('eine Atempause mitten im Satz beendet nicht', () {
      expect(schritt(seitStartMs: 4000, seitStimmeMs: 900),
          Aufnahmeschritt.weiter);
    });

    test('nach anderthalb Sekunden Stille ist der Satz zu Ende', () {
      expect(schritt(seitStartMs: 4000, seitStimmeMs: 1600),
          Aufnahmeschritt.beenden);
    });

    test('irgendwann ist Schluss, auch wenn jemand durchredet', () {
      expect(schritt(seitStartMs: 15500, seitStimmeMs: 0),
          Aufnahmeschritt.beenden);
    });
  });
}

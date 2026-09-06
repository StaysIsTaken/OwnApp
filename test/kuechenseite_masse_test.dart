// Die Masse der Kuechenseite.
//
// Anlass: unter dem Kalender blieb ein schwarzer Streifen stehen. Er war
// einmal Platz fuer die schwebenden Knoepfe -- seit die ins Menue gewandert
// sind, gibt es sie im Normalbetrieb nicht mehr, der reservierte Rand aber
// schon.
//
// Die Seite selbst laesst sich nicht zeichnen (sie laedt beim Aufbau vom
// Server), die Rechnung dahinter schon. Deshalb steht sie in eigenen
// Funktionen.
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/tabs/tablet/tablet_seite.dart';

void main() {
  group('Rand unten', () {
    test('im Normalbetrieb nur ein schmaler Rand', () {
      expect(randUnten(false), 20);
    });

    test('beim Einrichten Platz fuer die Knoepfe', () {
      // Sonst verdecken sie die letzte Zeile des Kalenders.
      expect(randUnten(true), greaterThan(80));
    });
  });

  group('Hoehe einer Kachel, die die Breite braucht', () {
    test('allein auf der Seite nimmt sie alles bis auf die Raender', () {
      // Das ist der eigentliche Punkt: kein toter Streifen mehr.
      final h = hoeheGrosseKachel(
          verfuegbar: 900, bearbeiten: false, alleinAufDerSeite: true);
      expect(h, 900 - randOben - randUnten(false));
    });

    test('beim Einrichten bleibt unten Platz', () {
      final h = hoeheGrosseKachel(
          verfuegbar: 900, bearbeiten: true, alleinAufDerSeite: true);
      expect(h, 900 - randOben - randUnten(true));
      expect(h, lessThan(hoeheGrosseKachel(
          verfuegbar: 900, bearbeiten: false, alleinAufDerSeite: true)));
    });

    test('neben anderen Kacheln nimmt sie knapp zwei Drittel', () {
      final h = hoeheGrosseKachel(
          verfuegbar: 1000, bearbeiten: false, alleinAufDerSeite: false);
      expect(h, closeTo(620, 1));
    });

    test('auf einem kleinen Bildschirm bleibt sie lesbar', () {
      // Lieber scrollen als ein Wochenraster von 80 Pixeln Hoehe.
      final h = hoeheGrosseKachel(
          verfuegbar: 300, bearbeiten: false, alleinAufDerSeite: true);
      expect(h, greaterThanOrEqualTo(360));
    });

    test('auf einem sehr grossen Bildschirm wird sie neben anderen nicht endlos',
        () {
      final h = hoeheGrosseKachel(
          verfuegbar: 4000, bearbeiten: false, alleinAufDerSeite: false);
      expect(h, lessThanOrEqualTo(720));
    });
  });
}

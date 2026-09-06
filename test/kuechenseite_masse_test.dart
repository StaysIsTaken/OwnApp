// Die Masse der Kuechenseite.
//
// Anlass: unter dem Kalender blieb ein schwarzer Streifen stehen. Er war
// einmal Platz fuer die schwebenden Knoepfe -- seit die ins Menue gewandert
// sind, gibt es sie im Normalbetrieb nicht mehr, der reservierte Rand aber
// schon.
//
// Die Seite selbst laesst sich nicht zeichnen (sie laedt beim Aufbau vom
// Server), die Rechnung dahinter schon. Deshalb steht sie in eigenen
// Funktionen. Die Hoehe je Kachel steht inzwischen in kachel_layout.dart
// und wird dort geprueft.
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

}

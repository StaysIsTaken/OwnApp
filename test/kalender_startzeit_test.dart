// Die Wochenansicht faengt dort an, wo der Tag gerade steht.
//
// Vorher sprang sie auf eine feste 7 -- und selbst die kam meist nicht an:
// der Sprung lag in initState, und im TabBarView hat der Scroll-Controller
// beim ersten Frame oft noch keine Ausdehnung. maxScrollExtent war dann 0,
// das clamp machte daraus 0, und die Ansicht begann bei Mitternacht. Genau
// das ist dem Nutzer als „steht oben bei 1 Uhr" aufgefallen.
//
// Geprueft wird `zielStunde` -- die echte Funktion aus der Ansicht, nicht
// eine Kopie davon. Ein nachgebauter Test bliebe gruen, waehrend die
// Ansicht kaputt ist, und waere damit schlechter als keiner.

import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/widgets/kalender/wochenraster_teile.dart';

void main() {
  // Montag, 14.9.2026.
  final woche = DateTime(2026, 9, 14);

  group('Die angezeigte Woche ist die aktuelle', () {
    test('vormittags steht die aktuelle Stunde oben', () {
      expect(zielStunde(jetzt: DateTime(2026, 9, 16, 11, 0), wochenStart: woche),
          11.0);
    });

    test('die Minuten zaehlen mit', () {
      // Sonst spraenge 10:59 und 10:01 an dieselbe Stelle.
      expect(zielStunde(jetzt: DateTime(2026, 9, 16, 10, 30), wochenStart: woche),
          10.5);
    });

    test('kurz nach Mitternacht bleibt es ganz oben', () {
      // Der Vorlauf von einer Stunde wuerde negativ -- das faengt erst das
      // clamp in der Ansicht ab. Hier zaehlt nur, dass 0 herauskommt und
      // nicht der Vormittags-Rueckfall.
      expect(zielStunde(jetzt: DateTime(2026, 9, 14, 0, 30), wochenStart: woche),
          0.5);
    });

    test('der letzte Moment der Woche zaehlt noch dazu', () {
      expect(
          zielStunde(
              jetzt: DateTime(2026, 9, 20, 23, 0), wochenStart: woche),
          23.0);
    });
  });

  group('Die angezeigte Woche ist eine andere', () {
    test('blaettert man vor, faengt sie beim Vormittag an', () {
      // „Jetzt" sagt nichts ueber eine fremde Woche aus. Mitternacht waere
      // die schlechtere Antwort: man saehe sechs leere Stunden.
      expect(zielStunde(jetzt: DateTime(2026, 9, 16, 11, 0),
              wochenStart: DateTime(2026, 9, 21)),
          8.0);
    });

    test('blaettert man zurueck, ebenso', () {
      expect(zielStunde(jetzt: DateTime(2026, 9, 16, 11, 0),
              wochenStart: DateTime(2026, 9, 7)),
          8.0);
    });

    test('der erste Moment der naechsten Woche gehoert nicht mehr dazu', () {
      // Genau an der Grenze: Montag 00:00 der Folgewoche.
      expect(zielStunde(jetzt: DateTime(2026, 9, 21), wochenStart: woche), 8.0);
    });
  });
}

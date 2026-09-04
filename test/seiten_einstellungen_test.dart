// Was für eine ganze Übersichtsseite gilt – zuerst: welche Kalender sie
// zeigt. Das ist die Stelle, an der sich "Müllabfuhr nur auf dieser Seite"
// entscheidet, deshalb steht hier der Unterschied zwischen "alle" und
// "keiner" im Mittelpunkt.
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/tabs/dashboard/seiten_einstellungen.dart';

void main() {
  group('Alle, einige, keiner', () {
    test('ohne Auswahl zeigt die Seite alles', () {
      const e = SeitenEinstellungen.leer;
      expect(e.filtertKalender, isFalse);
      expect(e.zeigt(1), isTrue);
      expect(e.zeigt(99), isTrue);
      // Auch Termine ohne Kalender – die gibt es aus der Zeit davor.
      expect(e.zeigt(null), isTrue);
    });

    test('eine leere Liste heißt keiner, nicht alle', () {
      // Der Unterschied ist der ganze Punkt: ohne ihn ließe sich eine Seite
      // nie ganz leer schalten.
      const e = SeitenEinstellungen(kalender: []);
      expect(e.filtertKalender, isTrue);
      expect(e.zeigt(1), isFalse);
    });

    test('mit Auswahl zeigt sie nur die genannten', () {
      const e = SeitenEinstellungen(kalender: [2, 5]);
      expect(e.zeigt(2), isTrue);
      expect(e.zeigt(5), isTrue);
      expect(e.zeigt(3), isFalse);
    });

    test('ein Termin ohne Kalender fällt aus einer Auswahl heraus', () {
      // Sonst tauchte er auf jeder Seite auf, egal was eingestellt ist.
      const e = SeitenEinstellungen(kalender: [2]);
      expect(e.zeigt(null), isFalse);
    });
  });

  group('Speichern und zurücklesen', () {
    test('eine Auswahl überlebt den Weg durch JSON', () {
      const e = SeitenEinstellungen(kalender: [3, 7], alleKalender: true);
      final zurueck = SeitenEinstellungen.fromJson(e.toJson());
      expect(zurueck.kalender, [3, 7]);
      expect(zurueck.alleKalender, isTrue);
    });

    test('"alle" bleibt "alle" und wird nicht zur leeren Liste', () {
      // Ginge das schief, zeigte die Seite nach einem Neustart nichts mehr.
      final zurueck =
          SeitenEinstellungen.fromJson(SeitenEinstellungen.leer.toJson());
      expect(zurueck.kalender, isNull);
      expect(zurueck.filtertKalender, isFalse);
    });

    test('die leere Auswahl überlebt ebenfalls', () {
      const e = SeitenEinstellungen(kalender: []);
      expect(SeitenEinstellungen.fromJson(e.toJson()).kalender, isEmpty);
    });

    test('ohne gespeicherten Stand kommt der Normalfall', () {
      expect(SeitenEinstellungen.fromJson(null).filtertKalender, isFalse);
    });

    test('IDs als Text werden trotzdem gelesen', () {
      // JSON aus einer anderen Ecke liefert Zahlen gern als Strings.
      final e = SeitenEinstellungen.fromJson({'kalender': ['3', 8]});
      expect(e.kalender, [3, 8]);
    });

    test('Unsinn im gespeicherten Stand zerlegt die Seite nicht', () {
      // Lieber "alle zeigen" als eine Ausnahme beim Aufbau der Übersicht.
      expect(SeitenEinstellungen.fromJson({'kalender': 'kaputt'}).kalender,
          isNull);
    });
  });
}

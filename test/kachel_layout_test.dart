// Das Fliesslayout der Kuechenseite: welche Kachel neben welche kommt.
//
// Die Seite selbst laesst sich nicht zeichnen -- sie laedt beim Aufbau vom
// Server. Diese Rechnung schon, und sie entscheidet, wie die Seite aussieht.
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/tabs/dashboard/custom/tile_spec.dart';
import 'package:productivity/tabs/tablet/kachel_layout.dart';

CustomTile kachel(String id, {int breite = 1, int hoehe = 2}) => CustomTile(
      id: id, source: 'tasks.open', view: 'stat',
      breite: breite, hoehe: hoehe,
    );

List<List<String>> ids(List<List<CustomTile>> reihen) =>
    [for (final r in reihen) [for (final k in r) k.id]];

void main() {
  group('Automatisch', () {
    CustomTile mitAnsicht(String view) =>
        CustomTile(id: 'x', source: 's', view: view);

    test('ein Raster nimmt die ganze Reihe', () {
      // Kacheln, die vor dieser Einstellung angelegt wurden, haben keine
      // Groesse gespeichert – sie sollen aussehen wie bisher.
      for (final view in ['week', 'month', 'board', 'checklist']) {
        expect(breiteVon(mitAnsicht(view), 3), 3, reason: view);
        expect(hoeheVon(mitAnsicht(view)), CustomTile.maxHoehe, reason: view);
      }
    });

    test('alles andere bekommt eine Spalte', () {
      for (final view in ['stat', 'list', 'bars', 'pie', 'text']) {
        expect(breiteVon(mitAnsicht(view), 3), 1, reason: view);
        expect(hoeheVon(mitAnsicht(view)), lessThan(CustomTile.maxHoehe),
            reason: view);
      }
    });

    test('eine eingestellte Groesse schlaegt die Automatik', () {
      final k = CustomTile(
          id: 'x', source: 's', view: 'week', breite: 1, hoehe: 2);
      expect(breiteVon(k, 3), 1);
      expect(hoeheVon(k), 2);
    });

    test('eine unbekannte Darstellung faellt auf schmal zurueck', () {
      expect(breiteVon(mitAnsicht('gibtsnicht'), 3), 1);
    });

    test('automatisch ist der gespeicherte Zustand ohne Angabe', () {
      final k = CustomTile.fromJson({'id': 'a', 'source': 's', 'view': 'week'});
      expect(k.breiteAutomatisch, isTrue);
      expect(k.hoeheAutomatisch, isTrue);
    });

    test('eine gespeicherte Groesse ueberlebt JSON', () {
      const k = CustomTile(
          id: 'a', source: 's', view: 'stat', breite: 2, hoehe: 3);
      final zurueck = CustomTile.fromJson(k.toJson());
      expect(zurueck.breite, 2);
      expect(zurueck.hoehe, 3);
    });
  });

  group('Umbruch in Reihen', () {
    test('schmale Kacheln stehen nebeneinander', () {
      // Der eigentliche Wunsch: Einkaufsliste, daneben noch etwas.
      final r = inReihen([kachel('a'), kachel('b'), kachel('c')], 3);
      expect(ids(r), [['a', 'b', 'c']]);
    });

    test('was nicht mehr passt, beginnt eine neue Reihe', () {
      final r = inReihen([kachel('a', breite: 2), kachel('b', breite: 2)], 3);
      expect(ids(r), [['a'], ['b']]);
    });

    test('eine breite und eine schmale teilen sich die Reihe', () {
      final r = inReihen([kachel('breit', breite: 2), kachel('schmal')], 3);
      expect(ids(r), [['breit', 'schmal']]);
    });

    test('die Reihenfolge bleibt, wie sie gezogen wurde', () {
      // Umsortieren, um Luecken zu fuellen, waere klueger und zugleich
      // unbrauchbar: die Kacheln spraengen bei jeder Aenderung anderswohin.
      final r = inReihen(
        [kachel('a', breite: 3), kachel('b'), kachel('c')],
        3,
      );
      expect(ids(r), [['a'], ['b', 'c']]);
    });

    test('breiter als das Raster wird beschnitten', () {
      // Sonst ragte die Reihe ueber den Rand hinaus.
      final r = inReihen([kachel('riesig', breite: 4), kachel('b')], 2);
      expect(ids(r), [['riesig'], ['b']]);
    });

    test('ohne Kacheln keine Reihen', () {
      expect(inReihen(const [], 3), isEmpty);
    });

    test('bei einer Spalte steht alles untereinander', () {
      final r = inReihen([kachel('a'), kachel('b')], 1);
      expect(ids(r), [['a'], ['b']]);
    });
  });

  group('Spalten nach Breite', () {
    test('Telefon bekommt eine', () => expect(spaltenFuer(400), 1));
    test('Tablet hochkant bekommt zwei', () => expect(spaltenFuer(800), 2));
    test('grosses Tablet bekommt drei', () => expect(spaltenFuer(1200), 3));
    test('breiter Bildschirm bekommt vier', () => expect(spaltenFuer(1600), 4));

    test('mehr Breite ergibt nie weniger Spalten', () {
      var vorher = 0;
      for (var b = 300.0; b < 2000; b += 50) {
        final jetzt = spaltenFuer(b);
        expect(jetzt, greaterThanOrEqualTo(vorher));
        vorher = jetzt;
      }
    });
  });

  group('Hoehe nach Stufe', () {
    test('hoehere Stufe ist nie niedriger', () {
      var vorher = 0.0;
      for (var stufe = 1; stufe <= CustomTile.maxHoehe; stufe++) {
        final h = hoeheFuer(stufe, 1000);
        expect(h, greaterThan(vorher));
        vorher = h;
      }
    });

    test('die hoechste Stufe fuellt die Seite', () {
      expect(hoeheFuer(CustomTile.maxHoehe, 900), 900 - 40);
    });

    test('auf kleinem Bildschirm bleibt sie lesbar', () {
      expect(hoeheFuer(CustomTile.maxHoehe, 200), greaterThanOrEqualTo(320));
    });

    test('eine unsinnige Stufe wird beschnitten', () {
      expect(hoeheFuer(99, 1000), hoeheFuer(CustomTile.maxHoehe, 1000));
      expect(hoeheFuer(0, 1000), hoeheFuer(1, 1000));
    });
  });
}

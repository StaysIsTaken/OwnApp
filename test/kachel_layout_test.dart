// Das Fliesslayout der Kuechenseite: welche Kachel neben welche kommt.
//
// Die Seite selbst laesst sich nicht zeichnen -- sie laedt beim Aufbau vom
// Server. Diese Rechnung schon, und sie entscheidet, wie die Seite aussieht.
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/tabs/dashboard/custom/tile_spec.dart';
import 'package:productivity/tabs/dashboard/custom/tile_views.dart';
import 'package:productivity/tabs/tablet/kachel_layout.dart';

CustomTile kachel(String id, {int breite = 1, int hoehe = 2}) => CustomTile(
      id: id, source: 'tasks.open', view: 'stat',
      breite: breite, hoehe: hoehe,
    );

List<List<String>> ids(List<List<CustomTile>> reihen) =>
    [for (final r in reihen) [for (final k in r) k.id]];

void main() {
  _masse();

  group('Mindestmasse verschieben die Nachbarn', () {
    CustomTile mit(String id, String view, {int breite = 1}) =>
        CustomTile(id: id, source: 's', view: view, breite: breite);

    test('eine Wochenansicht laesst sich nicht auf eine Spalte zwingen', () {
      // Sieben Tagesspalten auf einem Viertel des Bildschirms waeren ein
      // Streifenmuster. Sie nimmt sich, was sie braucht.
      final k = mit('w', 'week', breite: 1);
      // 1200 Pixel, 4 Spalten -> 300 je Spalte, Mindestmass 460 -> 2 Spalten.
      expect(spaltenBedarf(k, 4, 1200), 2);
    });

    test('eine grosse Zahl bleibt schmal', () {
      expect(spaltenBedarf(mit('s', 'stat', breite: 1), 4, 1200), 1);
    });

    test('mehr eingestellt als noetig bleibt bestehen', () {
      // Das Mindestmass ist eine Untergrenze, keine Vorgabe.
      expect(spaltenBedarf(mit('s', 'stat', breite: 3), 4, 1200), 3);
    });

    test('auf einem schmalen Raster nimmt sie alles, was es gibt', () {
      // 600 Pixel, 2 Spalten -> 300 je Spalte, Mindestmass 460 -> beide.
      expect(spaltenBedarf(mit('w', 'week'), 2, 600), 2);
    });

    test('die Nachbarin rutscht in die naechste Reihe', () {
      // Der eigentliche Punkt: die erste Kachel verschiebt die zweite,
      // statt dass beide unlesbar werden.
      final r = inReihen(
        [mit('woche', 'week'), mit('liste', 'checklist')],
        3,
        rasterBreite: 900, // 300 je Spalte: Woche braucht 2, Liste 1
      );
      expect(ids(r), [['woche', 'liste']]);

      final eng = inReihen(
        [mit('woche', 'week'), mit('board', 'board')],
        3,
        rasterBreite: 900, // Woche 2 + Board 2 passt nicht in 3
      );
      expect(ids(eng), [['woche'], ['board']]);
    });

    test('ohne bekannte Rasterbreite bleibt es bei der Wunschbreite', () {
      // So verhielt es sich vorher – der Aufrufer muss die Breite nicht
      // kennen, dann gilt eben nur die Einstellung.
      expect(spaltenBedarf(mit('w', 'week', breite: 1), 4, 0), 1);
    });
  });

  group('Hoehe einer Reihe', () {
    CustomTile mit(String view, {int hoehe = 1}) =>
        CustomTile(id: view, source: 's', view: view, hoehe: hoehe);

    test('keine Kachel faellt unter ihr Mindestmass', () {
      // Stufe 1 waere 220 – die Wochenansicht braucht 260.
      final h = reihenHoehe([mit('week', hoehe: 1)], 1000);
      expect(h, greaterThanOrEqualTo(260));
    });

    test('die hoechste Kachel gibt der Reihe ihr Mass', () {
      final h = reihenHoehe([mit('stat', hoehe: 1), mit('week', hoehe: 3)], 1000);
      expect(h, hoeheFuer(3, 1000));
    });

    test('eine leere Reihe hat keine Hoehe', () {
      expect(reihenHoehe(const [], 1000), 0);
    });
  });

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

// Die Masse selbst: sie stehen jetzt an der Darstellung statt als geratene
// Zahl im Zeichencode.
void _masse() {
  group('Mindestmasse der Darstellungen', () {
    test('jede Darstellung nennt ein Mass', () {
      for (final v in TileViews.all) {
        expect(v.minBreite, greaterThan(0), reason: v.key);
        expect(v.minHoehe, greaterThan(0), reason: v.key);
      }
    });

    test('Raster brauchen mehr als Textbausteine', () {
      // Ein Wochenraster braucht sieben Spalten, eine grosse Zahl fast
      // nichts – sonst waere das Mass keine Auskunft.
      final woche = TileViews.byKey('week')!;
      final zahl = TileViews.byKey('stat')!;
      expect(woche.minBreite, greaterThan(zahl.minBreite));
      expect(woche.minHoehe, greaterThan(zahl.minHoehe));
    });

    test('die Einkaufsliste darf schmal sein', () {
      // Ein Einkaufszettel ist eine Spalte – Hoehe braucht er, Breite nicht.
      final liste = TileViews.byKey('checklist')!;
      expect(liste.minBreite, lessThan(TileViews.byKey('week')!.minBreite));
      expect(liste.minHoehe, greaterThan(200));
    });

    test('"gross" leitet sich vom eigenen Mass ab', () {
      // Kein geratener Schwellwert mehr: wer das Mindestmass aendert,
      // aendert die Schwelle mit.
      final v = TileViews.byKey('week')!;
      expect(v.istGross(v.minHoehe * TileView.grossAb), isTrue);
      expect(v.istGross(v.minHoehe), isFalse);
    });

    test('eine anspruchsvolle Darstellung wird spaeter gross', () {
      final woche = TileViews.byKey('week')!;
      final zahl = TileViews.byKey('stat')!;
      // Bei derselben Hoehe kann die genuegsame schon gross sein, die
      // anspruchsvolle noch nicht.
      expect(zahl.istGross(300), isTrue);
      expect(woche.istGross(300), isFalse);
    });
  });
}

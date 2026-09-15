import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/finanzen.dart';
import 'package:productivity/tabs/dashboard/custom/filter_fields.dart';
import 'package:productivity/tabs/dashboard/custom/tile_catalog.dart';
import 'package:productivity/tabs/dashboard/custom/tile_data.dart';
import 'package:productivity/tabs/dashboard/custom/tile_filter.dart';
import 'package:productivity/tabs/dashboard/custom/tile_spec.dart';

/// Die vier Kacheln des Haushaltsbuchs.
///
/// Sie rechnen aus dem, was die Übersicht ohnehin geladen hat — also
/// lassen sie sich mit einer von Hand gebauten [DashboardData] prüfen,
/// ohne Server und ohne Widget.
///
/// Worauf es ankommt:
///
/// **Ausgaben werden positiv gezeigt.** Eine Torte kann mit negativen
/// Werten nichts anfangen.
///
/// **Die Vorschau bleibt aussen vor.** `finanzen.faellig` kommt aus
/// [DashboardData.geplant], nie aus den Buchungen — was geplant ist, ist
/// nicht gebucht.
DateTime _imMonat(int versatz, int tag) {
  final heute = DateTime.now();
  final erster = DateTime(heute.year, heute.month + versatz, 1);
  final letzter = DateTime(erster.year, erster.month + 1, 0);
  return DateTime(erster.year, erster.month, tag.clamp(1, letzter.day));
}

Buchung _b(int id, int versatz, int cents,
        {String titel = 'Posten', int? kategorie, int tag = 10}) =>
    Buchung(
      id: id,
      kasseId: 1,
      kategorieId: kategorie,
      tag: _imMonat(versatz, tag),
      cents: cents,
      titel: titel,
    );

const _essen = Finanzkategorie(id: 1, name: 'Lebensmittel', color: '#22C55E');
const _wohnen = Finanzkategorie(id: 2, name: 'Wohnen', color: '#EF4444');

DashboardData _daten({
  List<Buchung> buchungen = const [],
  List<Geplant> geplant = const [],
}) =>
    DashboardData(
      buchungen: buchungen,
      geplant: geplant,
      finanzkategorien: const {1: _essen, 2: _wohnen},
    );

TileData _rechne(String key, DashboardData d,
    {Map<String, dynamic> params = const {}, List<FilterRule> filter = const []}) {
  final quelle = TileCatalog.byKey(key);
  expect(quelle, isNotNull, reason: 'Quelle $key fehlt im Katalog');
  return quelle!.build(d, params, filter);
}

void main() {
  group('Der Katalog kennt die vier Quellen', () {
    test('alle vier stehen drin und gehören zusammen', () {
      for (final key in const [
        'finanzen.saldo',
        'finanzen.kategorien',
        'finanzen.verlauf',
        'finanzen.faellig',
      ]) {
        final quelle = TileCatalog.byKey(key);
        expect(quelle, isNotNull, reason: key);
        expect(quelle!.group, 'Haushaltsbuch', reason: key);
      }
    });

    test('jede hat die Form, die ihre Darstellung braucht', () {
      expect(TileCatalog.byKey('finanzen.saldo')!.shape, TileShape.scalar);
      expect(TileCatalog.byKey('finanzen.kategorien')!.shape,
          TileShape.distribution);
      expect(TileCatalog.byKey('finanzen.verlauf')!.shape, TileShape.series);
      expect(TileCatalog.byKey('finanzen.faellig')!.shape, TileShape.list);
    });

    test('der Monatsversatz bleibt im geladenen Fenster', () {
      // Die Übersicht lädt dreizehn Monate zurück bis zum Ende des
      // nächsten. Liesse der Parameter mehr zu, stünde die Kachel leer
      // da, ohne dass man den Grund sähe.
      final p = TileCatalog.byKey('finanzen.saldo')!.params
          .firstWhere((p) => p.key == 'months');
      expect(p.min, greaterThanOrEqualTo(-12));
      expect(p.max, lessThanOrEqualTo(1));
    });
  });

  group('Saldo des Monats', () {
    test('Einnahmen minus Ausgaben, in Euro', () {
      final d = _daten(buchungen: [
        _b(1, 0, 250000, titel: 'Gehalt'),
        _b(2, 0, -4783, titel: 'Edeka'),
      ]);
      expect(_rechne('finanzen.saldo', d).value, closeTo(2452.17, 0.001));
    });

    test('ein anderer Monat zählt nicht mit', () {
      final d = _daten(buchungen: [
        _b(1, 0, -1000),
        _b(2, -1, -9999),
      ]);
      expect(_rechne('finanzen.saldo', d).value, closeTo(-10.0, 0.001));
    });

    test('der Versatz blättert zurück', () {
      final d = _daten(buchungen: [
        _b(1, 0, -1000),
        _b(2, -1, -2500),
      ]);
      final vorMonat = _rechne('finanzen.saldo', d, params: {'months': -1});
      expect(vorMonat.value, closeTo(-25.0, 0.001));
    });

    test('ohne Buchungen ist der Saldo null, nicht leer', () {
      expect(_rechne('finanzen.saldo', _daten()).value, 0);
    });
  });

  group('Ausgaben nach Kategorie', () {
    test('Ausgaben kommen positiv und größte zuerst', () {
      final d = _daten(buchungen: [
        _b(1, 0, -32000, kategorie: 1),
        _b(2, 0, -1000, kategorie: 1),
        _b(3, 0, -95000, kategorie: 2),
      ]);
      final daten = _rechne('finanzen.kategorien', d);
      expect(daten.points.keys.toList(), ['Wohnen', 'Lebensmittel']);
      expect(daten.points['Wohnen'], closeTo(950.0, 0.001));
      expect(daten.points['Lebensmittel'], closeTo(330.0, 0.001));
    });

    test('Einnahmen gehören nicht in die Ausgabenverteilung', () {
      final d = _daten(buchungen: [
        _b(1, 0, -1000, kategorie: 1),
        _b(2, 0, 250000, titel: 'Gehalt'),
      ]);
      final daten = _rechne('finanzen.kategorien', d);
      expect(daten.points.length, 1);
      expect(daten.points['Lebensmittel'], closeTo(10.0, 0.001));
    });

    test('ohne Kategorie fällt nichts unter den Tisch', () {
      // Sonst fehlte ein Teil der Ausgaben in der Torte, ohne dass es
      // auffiele.
      final d = _daten(buchungen: [_b(1, 0, -500)]);
      final daten = _rechne('finanzen.kategorien', d);
      expect(daten.points['Ohne Kategorie'], closeTo(5.0, 0.001));
    });
  });

  group('Ausgaben je Monat', () {
    test('ein Punkt je Monat, ältester zuerst', () {
      final d = _daten(buchungen: [
        _b(1, 0, -1000),
        _b(2, -1, -2000),
        _b(3, -2, -3000),
      ]);
      final daten = _rechne('finanzen.verlauf', d, params: {'span': 3});
      expect(daten.points.length, 3);
      expect(daten.points.values.toList(),
          [closeTo(30.0, 0.001), closeTo(20.0, 0.001), closeTo(10.0, 0.001)]);
    });

    test('Monate ohne Ausgaben stehen als null da, nicht als Lücke', () {
      // Eine Linie mit Lücken liest sich als „keine Daten", nicht als
      // „nichts ausgegeben".
      final d = _daten(buchungen: [_b(1, 0, -1000)]);
      final daten = _rechne('finanzen.verlauf', d, params: {'span': 3});
      expect(daten.points.length, 3);
      expect(daten.points.values.first, 0);
    });

    test('Einnahmen verfälschen den Verlauf nicht', () {
      final d = _daten(buchungen: [
        _b(1, 0, -1000),
        _b(2, 0, 250000),
      ]);
      final daten = _rechne('finanzen.verlauf', d, params: {'span': 1});
      expect(daten.points.values.single, closeTo(10.0, 0.001));
    });
  });

  group('Was noch kommt', () {
    test('kommt aus der Vorschau, nicht aus den Buchungen', () {
      final d = _daten(
        buchungen: [_b(1, 0, -9999, titel: 'Gebucht')],
        geplant: [
          Geplant(
              serieId: 1,
              kasseId: 1,
              tag: _imMonat(0, 28),
              cents: -95000,
              titel: 'Miete'),
        ],
      );
      final daten = _rechne('finanzen.faellig', d);
      expect(daten.items.length, 1);
      expect(daten.items.single.title, 'Miete');
    });

    test('früheste Fälligkeit zuerst', () {
      final d = _daten(geplant: [
        Geplant(
            serieId: 1, kasseId: 1, tag: _imMonat(1, 15),
            cents: -100, titel: 'Später'),
        Geplant(
            serieId: 2, kasseId: 1, tag: _imMonat(0, 2),
            cents: -100, titel: 'Früher'),
      ]);
      final daten = _rechne('finanzen.faellig', d);
      expect(daten.items.first.title, 'Früher');
    });

    test('ohne Daueraufträge steht ein Hinweis statt einer leeren Fläche', () {
      final daten = _rechne('finanzen.faellig', _daten());
      expect(daten.items, isEmpty);
      expect(daten.emptyHint, isNotNull);
    });
  });

  group('Filter', () {
    test('greifen auf Buchungen', () {
      final d = _daten(buchungen: [
        _b(1, 0, -32000, titel: 'Edeka'),
        _b(2, 0, -1000, titel: 'Bäcker'),
      ]);
      final nurGross = [
        FilterRule(field: 'amount', op: FilterOp.greater, value: '100'),
      ];
      final daten =
          _rechne('finanzen.saldo', d, filter: nurGross);
      expect(daten.value, closeTo(-320.0, 0.001));
    });

    test('Richtung ist ein eigenes Feld, kein negativer Betrag', () {
      // „Betrag > 50" meint die Höhe. Die Richtung daneben zu stellen ist
      // verständlicher, als negative Zahlen ins Filterfeld zu tippen.
      final feld = FilterFields.buchungen['direction'];
      expect(feld, isNotNull);
      expect(feld!.choices, ['Ausgabe', 'Einnahme']);
      expect(feld.read(_b(1, 0, -100)), 'Ausgabe');
      expect(feld.read(_b(2, 0, 100)), 'Einnahme');
    });

    test('der Betrag kommt ohne Vorzeichen und in Euro', () {
      final feld = FilterFields.buchungen['amount']!;
      expect(feld.read(_b(1, 0, -4783)), closeTo(47.83, 0.001));
      expect(feld.read(_b(2, 0, 4783)), closeTo(47.83, 0.001));
    });
  });

  group('zeigtFinanzen', () {
    test('erkennt eine Finanzkachel', () {
      expect(
        TileCatalog.zeigtFinanzen(
            [CustomTile(id: 'a', source: 'finanzen.saldo', view: 'zahl')]),
        isTrue,
      );
    });

    test('und lässt andere Seiten in Ruhe', () {
      // Sonst löste jede Tablet-Seite drei zusätzliche Abfragen aus – und
      // ein Gerät an der Küchenwand zöge Kontostände, die niemand dort
      // haben wollte.
      expect(
        TileCatalog.zeigtFinanzen(
            [CustomTile(id: 'a', source: 'planner.week', view: 'woche')]),
        isFalse,
      );
      expect(TileCatalog.zeigtFinanzen(const []), isFalse);
    });
  });
}

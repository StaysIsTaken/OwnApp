// Der Baukasten: Quellen rechnen aus den geladenen Daten, Darstellungen
// erklären welche Datenformen sie können. Beides ohne Widgets testbar.
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/task.dart';
import 'package:productivity/dataclasses/time_entry.dart';
import 'package:productivity/tabs/dashboard/custom/tile_catalog.dart';
import 'package:productivity/tabs/dashboard/custom/tile_data.dart';
import 'package:productivity/tabs/dashboard/custom/tile_filter.dart';
import 'package:productivity/tabs/dashboard/custom/tile_spec.dart';
import 'package:productivity/tabs/dashboard/custom/tile_views.dart';

Task aufgabe({String id = 't', bool erledigt = false, DateTime? faellig,
    String spalte = 'todo'}) =>
    Task(
      id: id, title: 'Aufgabe $id', completed: erledigt, dueDate: faellig,
      userId: 'u', createdAt: DateTime(2026), updatedAt: DateTime(2026),
      kanbanState: spalte, priority: 'medium',
    );

TimeEntry zeit(DateTime start, Duration dauer) => TimeEntry(
      id: 'z${start.millisecondsSinceEpoch}',
      date: DateTime(start.year, start.month, start.day),
      startTime: start,
      endTime: start.add(dauer),
      description: '',
    );

void main() {
  final heute = DateTime.now();

  group('Katalog', () {
    test('jede Quelle hat einen eindeutigen Schlüssel', () {
      final keys = TileCatalog.sources.map((s) => s.key).toList();
      expect(keys.toSet().length, keys.length);
    });

    test('jede Quelle findet sich über byKey wieder', () {
      for (final s in TileCatalog.sources) {
        expect(TileCatalog.byKey(s.key), same(s));
      }
    });

    test('unbekannte Quelle ergibt null statt eines Fehlers', () {
      expect(TileCatalog.byKey('gibtsnicht'), isNull);
    });

    test('zu jeder Quelle gibt es mindestens eine Darstellung', () {
      for (final s in TileCatalog.sources) {
        expect(TileViews.forShape(s.shape), isNotEmpty,
            reason: 'Keine Darstellung für ${s.key} (${s.shape})');
      }
    });

    test('Quellen sind nach Bereich gruppiert', () {
      expect(TileCatalog.grouped.keys, contains('Zeiterfassung'));
      expect(TileCatalog.grouped['Aufgaben'], isNotEmpty);
    });
  });

  group('Darstellungen', () {
    test('nehmen nur passende Datenformen an', () {
      expect(TileViews.byKey('stat')!.accepts, contains(TileShape.scalar));
      expect(TileViews.byKey('stat')!.accepts, isNot(contains(TileShape.list)));
      expect(TileViews.byKey('bars')!.accepts, contains(TileShape.series));
      expect(TileViews.byKey('bars')!.accepts, contains(TileShape.distribution));
    });

    test('forShape liefert nur Passendes', () {
      for (final v in TileViews.forShape(TileShape.list)) {
        expect(v.accepts, contains(TileShape.list));
      }
    });
  });

  group('Quellen rechnen richtig', () {
    test('offene Aufgaben zählt nur unerledigte', () {
      final d = DashboardData(tasks: [
        aufgabe(id: 'a'),
        aufgabe(id: 'b', erledigt: true),
        aufgabe(id: 'c'),
      ]);
      final r = TileCatalog.byKey('tasks.open')!.build(d, {}, const []);
      expect(r.shape, TileShape.scalar);
      expect(r.value, 2);
    });

    test('Aufgaben je Spalte verteilt korrekt', () {
      final d = DashboardData(tasks: [
        aufgabe(id: 'a', spalte: 'todo'),
        aufgabe(id: 'b', spalte: 'todo'),
        aufgabe(id: 'c', spalte: 'done'),
      ]);
      final r = TileCatalog.byKey('tasks.by_state')!.build(d, {}, const []);
      expect(r.points['todo'], 2);
      expect(r.points['done'], 1);
    });

    test('fällige Aufgaben achten auf den Zeitraum', () {
      final d = DashboardData(tasks: [
        aufgabe(id: 'bald', faellig: heute.add(const Duration(days: 2))),
        aufgabe(id: 'spaet', faellig: heute.add(const Duration(days: 40))),
      ]);
      final r = TileCatalog.byKey('tasks.due')!.build(d, {'days': 7, 'limit': 5}, const []);
      expect(r.items, hasLength(1));
      expect(r.items.first.title, contains('bald'));
    });

    test('Anzahl wird durch limit begrenzt', () {
      final d = DashboardData(tasks: [
        for (var i = 0; i < 10; i++)
          aufgabe(id: '$i', faellig: heute.add(Duration(days: i + 1))),
      ]);
      final r = TileCatalog.byKey('tasks.due')!.build(d, {'days': 30, 'limit': 3}, const []);
      expect(r.items, hasLength(3));
    });

    test('gestempelte Zeit summiert je Tag', () {
      final gestern = DateTime(heute.year, heute.month, heute.day)
          .subtract(const Duration(days: 1))
          .add(const Duration(hours: 9));
      final d = DashboardData(timeEntries: [
        zeit(gestern, const Duration(hours: 2)),
        zeit(gestern.add(const Duration(hours: 4)), const Duration(hours: 1)),
      ]);
      final r = TileCatalog.byKey('time.per_day')!.build(d, {'days': 7}, const []);
      expect(r.shape, TileShape.series);
      // Sieben Tage im Fenster, auch die leeren.
      expect(r.points, hasLength(7));
      expect(r.points.values.reduce((a, b) => a + b), closeTo(3.0, 0.01));
    });

    test('laufender Eintrag ohne Ende wird übersprungen', () {
      final offen = TimeEntry(
        id: 'offen',
        date: DateTime(heute.year, heute.month, heute.day),
        startTime: heute.subtract(const Duration(hours: 1)),
        endTime: null,
        description: '',
      );
      final r = TileCatalog.byKey('time.total')!
          .build(DashboardData(timeEntries: [offen]), {'days': 7}, const []);
      expect(r.value, 0);
    });

    test('leere Daten melden isEmpty statt zu werfen', () {
      for (final s in TileCatalog.sources) {
        final r = s.build(const DashboardData(), {}, const []);
        expect(() => r.isEmpty, returnsNormally, reason: s.key);
      }
    });
  });

  group('Kachel-Definition', () {
    test('überlebt den Weg durch JSON', () {
      const t = CustomTile(
        id: 'ct_1', source: 'time.per_day', view: 'bars',
        title: 'Meine Woche', params: {'days': 14},
      );
      final zurueck = CustomTile.fromJson(t.toJson());
      expect(zurueck.id, t.id);
      expect(zurueck.source, t.source);
      expect(zurueck.view, t.view);
      expect(zurueck.title, t.title);
      expect(zurueck.params['days'], 14);
    });

    test('fehlende Felder ergeben leere Werte statt eines Fehlers', () {
      final t = CustomTile.fromJson({'id': 'x'});
      expect(t.id, 'x');
      expect(t.params, isEmpty);
      expect(t.title, isNull);
    });
  });

  group('Filter', () {
    test('Operatoren richten sich nach dem Datentyp', () {
      expect(operatorsFor(FieldType.boolean),
          [FilterOp.isTrue, FilterOp.isFalse]);
      expect(operatorsFor(FieldType.number), contains(FilterOp.greater));
      expect(operatorsFor(FieldType.text), contains(FilterOp.contains));
      expect(operatorsFor(FieldType.text), isNot(contains(FilterOp.greater)));
      expect(operatorsFor(FieldType.date), contains(FilterOp.lastDays));
    });

    test('nur ja/nein-Operatoren brauchen keinen Wert', () {
      expect(FilterOp.isTrue.needsValue, isFalse);
      expect(FilterOp.greater.needsValue, isTrue);
    });

    test('Zahlenvergleich', () {
      final feld = {
        'p': FilterField(
          key: 'p', label: 'Prio', type: FieldType.number,
          read: (e) => (e as Map)['p'],
        )
      };
      final daten = [
        {'p': 1}, {'p': 5}, {'p': 10}
      ];
      final r = applyFilters(daten,
          [const FilterRule(field: 'p', op: FilterOp.greater, value: '4')], feld);
      expect(r, hasLength(2));
    });

    test('Textsuche ist unabhängig von Groß- und Kleinschreibung', () {
      final feld = {
        't': FilterField(
          key: 't', label: 'Titel', type: FieldType.text,
          read: (e) => (e as Map)['t'],
        )
      };
      final daten = [
        {'t': 'Einkaufen gehen'}, {'t': 'Wäsche'}
      ];
      final r = applyFilters(daten,
          [const FilterRule(field: 't', op: FilterOp.contains, value: 'EINKAUF')],
          feld);
      expect(r, hasLength(1));
    });

    test('mehrere Bedingungen wirken als UND', () {
      final felder = {
        'a': FilterField(key: 'a', label: 'A', type: FieldType.number,
            read: (e) => (e as Map)['a']),
        'b': FilterField(key: 'b', label: 'B', type: FieldType.boolean,
            read: (e) => (e as Map)['b']),
      };
      final daten = [
        {'a': 10, 'b': true},
        {'a': 10, 'b': false},
        {'a': 1, 'b': true},
      ];
      final r = applyFilters(daten, const [
        FilterRule(field: 'a', op: FilterOp.greaterOrEqual, value: '5'),
        FilterRule(field: 'b', op: FilterOp.isTrue),
      ], felder);
      expect(r, hasLength(1));
    });

    test('unbekanntes Feld filtert nicht alles weg', () {
      // Etwa eine Kachel aus einer neueren Version: die Regel wird
      // uebersprungen, statt die Kachel leer zu lassen.
      final daten = [
        {'x': 1}, {'x': 2}
      ];
      final r = applyFilters(daten,
          [const FilterRule(field: 'gibtsnicht', op: FilterOp.equals, value: '1')],
          {});
      expect(r, hasLength(2));
    });

    test('ohne Regeln bleibt alles', () {
      final daten = [1, 2, 3];
      expect(applyFilters(daten, const [], {}), hasLength(3));
    });

    test('Regel überlebt den Weg durch JSON', () {
      const r = FilterRule(field: 'dauer', op: FilterOp.greater, value: '2');
      final zurueck = FilterRule.fromJson(r.toJson());
      expect(zurueck!.field, 'dauer');
      expect(zurueck.op, FilterOp.greater);
      expect(zurueck.value, '2');
    });

    test('kaputte Regel ergibt null statt eines Fehlers', () {
      expect(FilterRule.fromJson({'op': 'gibtsnicht'}), isNull);
      expect(FilterRule.fromJson({'field': ''}), isNull);
    });

    test('Kachel mit Filtern überlebt JSON', () {
      const t = CustomTile(
        id: 'x', source: 'time.per_day', view: 'bars',
        filters: [FilterRule(field: 'duration', op: FilterOp.greater, value: '1')],
      );
      final zurueck = CustomTile.fromJson(t.toJson());
      expect(zurueck.filters, hasLength(1));
      expect(zurueck.filters.first.field, 'duration');
    });

    test('filterbare Quellen haben Felder, andere nicht', () {
      for (final s in TileCatalog.sources) {
        if (s.filterable) {
          expect(s.fields, isNotEmpty, reason: s.key);
        }
      }
    });

    test('jede Quelle hat eine Route zum Anklicken', () {
      for (final s in TileCatalog.sources) {
        expect(s.route, isNotNull, reason: 'Keine Route für ${s.key}');
      }
    });
  });
}

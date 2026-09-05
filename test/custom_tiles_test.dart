// Der Baukasten: Quellen rechnen aus den geladenen Daten, Darstellungen
// erklären welche Datenformen sie können. Beides ohne Widgets testbar.
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/dataclasses/task.dart';
import 'package:productivity/dataclasses/time_entry.dart';
import 'package:productivity/dataservice/feed_service.dart';
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
  _wochenansicht();

  _monatsansicht();

  _kopfbloecke();

  _aktionen();

  _vonDraussen();

  _diagramme();

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

    test('wer filtern kann, führt auch irgendwohin', () {
      // Filtern heißt: die Quelle liest einen Datenbereich der App. Dann
      // soll ein Tippen dorthin führen. Rein eigene Blöcke wie "Eigener
      // Text" oder ein Countdown lesen nichts und führen deshalb nirgendwo
      // hin — bei denen wäre eine Route sogar irreführend.
      for (final s in TileCatalog.sources) {
        if (!s.filterable) continue;
        expect(s.route, isNotNull, reason: 'Keine Route für ${s.key}');
      }
    });

    test('Quellen ohne Datenbezug haben auch keine Filterfelder', () {
      for (final s in TileCatalog.sources) {
        if (s.route != null) continue;
        expect(s.fields, isEmpty, reason: s.key);
      }
    });
  });
}

// ── Diagramme und die neuen Quellen ────────────────────────────────────

void _diagramme() {
  group('Darstellungen passen zur Datenform', () {
    test('Torte nimmt nur Verteilungen', () {
      // Ein Kuchenstück je Tag wäre zeichenbar, würde aber nichts aussagen.
      final torte = TileViews.byKey('pie')!;
      expect(torte.accepts.contains(TileShape.distribution), isTrue);
      expect(torte.accepts.contains(TileShape.series), isFalse);
    });

    test('Linie nimmt nur Verläufe', () {
      // Eine Linie durch Kategorien suggeriert einen Zusammenhang, den es
      // nicht gibt.
      final linie = TileViews.byKey('line')!;
      expect(linie.accepts, {TileShape.series});
    });

    test('Balken nehmen beides', () {
      expect(TileViews.byKey('bars')!.accepts,
          {TileShape.series, TileShape.distribution});
    });

    test('zu jeder Datenform gibt es mindestens eine Darstellung', () {
      for (final form in TileShape.values) {
        expect(TileViews.forShape(form), isNotEmpty, reason: form.name);
      }
    });

    test('jede Quelle findet eine passende Darstellung', () {
      // Sonst stünde im Editor eine Quelle, die sich nicht anzeigen lässt.
      for (final quelle in TileCatalog.sources) {
        expect(TileViews.forShape(quelle.shape), isNotEmpty,
            reason: quelle.key);
      }
    });
  });

  group('Neue Quellen', () {
    test('es gibt jetzt mehrere Verteilungen für Tortendiagramme', () {
      final verteilungen = TileCatalog.sources
          .where((q) => q.shape == TileShape.distribution)
          .map((q) => q.key)
          .toList();
      expect(verteilungen.length, greaterThanOrEqualTo(4), reason: '$verteilungen');
    });

    test('Quellenschlüssel sind eindeutig', () {
      final keys = TileCatalog.sources.map((q) => q.key).toList();
      expect(keys.length, keys.toSet().length);
    });

    test('jede Quelle hat einen Bereich und eine Beschriftung', () {
      for (final q in TileCatalog.sources) {
        expect(q.label.trim(), isNotEmpty, reason: q.key);
        expect(q.group.trim(), isNotEmpty, reason: q.key);
      }
    });
  });
}

// ── Kopfblöcke ─────────────────────────────────────────────────────────

void _kopfbloecke() {
  group('Bereich einer Kachel', () {
    test('ohne Angabe liegt sie im Raster', () {
      // Kacheln aus der Zeit vor den Kopfblöcken sollen bleiben, wo sie waren.
      final t = CustomTile.fromJson({
        'id': 'x', 'source': 'tasks.open', 'view': 'stat',
      });
      expect(t.zone, CustomTile.zoneRaster);
      expect(t.imKopf, isFalse);
    });

    test('der Bereich übersteht das Speichern', () {
      const t = CustomTile(
        id: 'x', source: 'kopf.text', view: 'text',
        zone: CustomTile.zoneKopf,
      );
      expect(CustomTile.fromJson(t.toJson()).imKopf, isTrue);
    });

    test('ein unbekannter Bereich landet im Raster', () {
      final t = CustomTile.fromJson({
        'id': 'x', 'source': 'kopf.text', 'view': 'text', 'zone': 'irgendwas',
      });
      expect(t.zone, CustomTile.zoneRaster);
    });

    test('copyWith behält den Bereich', () {
      const t = CustomTile(
        id: 'x', source: 'kopf.text', view: 'text',
        zone: CustomTile.zoneKopf,
      );
      expect(t.copyWith(title: 'Neu').imKopf, isTrue);
    });
  });

  group('Kopfquellen', () {
    test('es gibt Textquellen und eine Darstellung dafür', () {
      final texte = TileCatalog.sources
          .where((q) => q.shape == TileShape.text)
          .toList();
      expect(texte, isNotEmpty);
      expect(TileViews.forShape(TileShape.text), isNotEmpty);
    });

    test('Eigener Text nimmt, was der Nutzer schreibt', () {
      final quelle = TileCatalog.byKey('kopf.text')!;
      final d = quelle.build(DashboardData(), {'text': 'Hallo Welt'}, const []);
      expect(d.body, 'Hallo Welt');
      expect(d.isEmpty, isFalse);
    });

    test('Eigener Text ohne Inhalt gilt als leer', () {
      final quelle = TileCatalog.byKey('kopf.text')!;
      expect(quelle.build(DashboardData(), const {}, const []).isEmpty, isTrue);
      expect(quelle.build(DashboardData(), {'text': '   '}, const []).isEmpty,
          isTrue);
    });

    test('Countdown zählt vorwärts und rückwärts', () {
      final quelle = TileCatalog.byKey('kopf.countdown')!;
      final in5 = DateTime.now().add(const Duration(days: 5));
      final vor3 = DateTime.now().subtract(const Duration(days: 3));
      String iso(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, "0")}-'
          '${d.day.toString().padLeft(2, "0")}';

      final a = quelle.build(DashboardData(), {'datum': iso(in5)}, const []);
      expect(a.value, 5);
      expect(a.unit, contains('noch'));

      final b = quelle.build(DashboardData(), {'datum': iso(vor3)}, const []);
      expect(b.value, 3);
      expect(b.unit, contains('her'));
    });

    test('Countdown ohne Datum zeigt nichts an', () {
      final quelle = TileCatalog.byKey('kopf.countdown')!;
      expect(quelle.build(DashboardData(), const {}, const []).isEmpty, isTrue);
      expect(
          quelle.build(DashboardData(), {'datum': 'kein datum'}, const []).isEmpty,
          isTrue);
    });

    test('Spruch des Tages bleibt über den Tag derselbe', () {
      // Sonst springt der Text bei jedem Neuzeichnen und man liest ihn nie
      // zu Ende.
      final quelle = TileCatalog.byKey('kopf.quote')!;
      final a = quelle.build(DashboardData(), const {}, const []);
      final b = quelle.build(DashboardData(), const {}, const []);
      expect(a.body, b.body);
      expect(a.body, isNotEmpty);
    });
  });
}

// ── Wochenansicht ──────────────────────────────────────────────────────

void _wochenansicht() {
  PlannerEntry termin(String titel, DateTime start, {int stunden = 1}) =>
      PlannerEntry(
        id: start.millisecondsSinceEpoch,
        userId: 'u',
        title: titel,
        scheduledAt: start,
        endsAt: start.add(Duration(hours: stunden)),
        createdAt: start,
      );

  DateTime montagDieserWoche() {
    final h = DateTime.now();
    final m = h.subtract(Duration(days: h.weekday - 1));
    return DateTime(m.year, m.month, m.day);
  }

  group('Wochenansicht', () {
    test('nimmt nur die gewählte Woche', () {
      final montag = montagDieserWoche();
      final d = DashboardData(plannerEntries: [
        termin('Diese Woche', montag.add(const Duration(days: 2, hours: 10))),
        termin('Nächste Woche', montag.add(const Duration(days: 9, hours: 10))),
        termin('Letzte Woche', montag.subtract(const Duration(days: 3))),
      ]);

      final r = TileCatalog.byKey('planner.week')!.build(d, {}, const []);
      expect(r.shape, TileShape.schedule);
      expect(r.schedule.map((e) => e.title), ['Diese Woche']);
    });

    test('der Versatz verschiebt die Woche', () {
      final montag = montagDieserWoche();
      final d = DashboardData(plannerEntries: [
        termin('Diese', montag.add(const Duration(days: 1, hours: 9))),
        termin('Nächste', montag.add(const Duration(days: 8, hours: 9))),
      ]);
      final quelle = TileCatalog.byKey('planner.week')!;

      expect(quelle.build(d, {'weeks': 0}, const []).schedule.single.title,
          'Diese');
      expect(quelle.build(d, {'weeks': 1}, const []).schedule.single.title,
          'Nächste');
    });

    test('rückwärts geht auch', () {
      // Auf dem Tablet will man auch nachsehen, was letzte Woche war.
      final montag = montagDieserWoche();
      final d = DashboardData(plannerEntries: [
        termin('Vergangen', montag.subtract(const Duration(days: 6))),
      ]);
      expect(
        TileCatalog.byKey('planner.week')!
            .build(d, {'weeks': -1}, const []).schedule.single.title,
        'Vergangen',
      );
    });

    test('Untertermine bleiben draußen', () {
      // Sie gehören zu ihrem Haupttermin und würden das Raster verdoppeln.
      final montag = montagDieserWoche();
      final haupt = termin('Haupt', montag.add(const Duration(days: 1, hours: 9)));
      final kind = PlannerEntry(
        id: 999, userId: 'u', title: 'Unterpunkt', parentId: haupt.id,
        scheduledAt: haupt.scheduledAt, endsAt: haupt.endsAt,
        createdAt: haupt.scheduledAt,
      );
      final d = DashboardData(plannerEntries: [haupt, kind]);

      expect(
        TileCatalog.byKey('planner.week')!
            .build(d, {}, const []).schedule.map((e) => e.title),
        ['Haupt'],
      );
    });

    test('leere Woche gilt als leer', () {
      final r = TileCatalog.byKey('planner.week')!
          .build(const DashboardData(), {}, const []);
      expect(r.isEmpty, isTrue);
      expect(r.emptyHint, isNotEmpty);
    });

    test('Termine nehmen nur Kalenderdarstellungen', () {
      // Stand hier frueher als 'genau week' – seit es die Monatsansicht
      // gibt, war das zu eng. Gemeint war immer: eine Torte oder eine Linie
      // kann mit Terminen nichts anfangen.
      final passende =
          TileViews.forShape(TileShape.schedule).map((v) => v.key).toSet();
      expect(passende, {'week', 'month'});
      for (final key in ['pie', 'bars', 'line', 'stat', 'list', 'text']) {
        expect(passende, isNot(contains(key)));
      }
    });
  });
}


// ── Kleine Aktionen je Kachel ──────────────────────────────────────────

void _aktionen() {
  group('Aktionen', () {
    test('die Wochenansicht kann einen Termin anlegen', () {
      // Der eigentliche Punkt: wer sieht, dass Mittwoch frei ist, soll ihn
      // dort eintragen können statt erst durch die App zu wandern.
      final aktion = TileCatalog.byKey('planner.week')!.aktion;
      expect(aktion, isNotNull);
      expect(aktion!.recht, 'planner:write');
    });

    test('die Aufgabenkacheln können eine Aufgabe anlegen', () {
      for (final key in ['tasks.open', 'tasks.due']) {
        final aktion = TileCatalog.byKey(key)!.aktion;
        expect(aktion, isNotNull, reason: '\$key hat keine Aktion');
        expect(aktion!.recht, 'tasks:write');
      }
    });

    test('reine Auswertungen haben keine Aktion', () {
      // Eine Verteilung "anzulegen" ergibt keinen Sinn – der Knopf wäre nur
      // im Weg.
      for (final key in ['tasks.by_state', 'time.per_day', 'planner.by_type']) {
        expect(TileCatalog.byKey(key)!.aktion, isNull, reason: key);
      }
    });

    test('jede Aktion nennt ein Recht aus dem Katalog', () {
      // Ein Tippfehler im Recht hieße: der Knopf erscheint nie, ohne dass es
      // jemandem auffällt.
      const bekannt = {'planner:write', 'tasks:write'};
      for (final s in TileCatalog.sources) {
        final r = s.aktion?.recht;
        if (r != null) expect(bekannt, contains(r), reason: s.key);
      }
    });

    test('jede Aktion hat eine Beschriftung', () {
      for (final s in TileCatalog.sources) {
        if (s.aktion != null) expect(s.aktion!.label, isNotEmpty, reason: s.key);
      }
    });
  });
}

// ── Nachrichten und Witze ──────────────────────────────────────────────

void _vonDraussen() {
  Meldung meldung(String titel, {String text = '', String ressort = ''}) =>
      Meldung(titel: titel, text: text, ressort: ressort, quelle: 'tagesschau.de');

  group('Von draußen', () {
    test('Nachrichten werden zur Liste', () {
      final quelle = TileCatalog.byKey('kopf.nachrichten')!;
      final d = quelle.build(
        DashboardData(nachrichten: [meldung('Erstes', text: 'Dazu ein Satz.')]),
        const {'anzahl': 3},
        const [],
      );
      expect(d.items.first.title, 'Erstes');
      expect(d.items.first.subtitle, 'Dazu ein Satz.');
    });

    test('die eingestellte Anzahl schneidet zu', () {
      final quelle = TileCatalog.byKey('kopf.nachrichten')!;
      final d = quelle.build(
        DashboardData(nachrichten: [
          for (var i = 0; i < 8; i++) meldung('M\$i'),
        ]),
        const {'anzahl': 2},
        const [],
      );
      expect(d.items.length, 2);
    });

    test('ohne Meldungen steht ein Hinweis statt einer leeren Fläche', () {
      final d = TileCatalog.byKey('kopf.nachrichten')!
          .build(const DashboardData(), const {}, const []);
      expect(d.isEmpty, isTrue);
      expect(d.emptyHint, isNotEmpty);
    });

    test('die Schlagzeile nimmt die erste Meldung', () {
      final d = TileCatalog.byKey('kopf.schlagzeile')!.build(
        DashboardData(nachrichten: [
          meldung('Ganz oben', ressort: 'inland'),
          meldung('Darunter'),
        ]),
        const {},
        const [],
      );
      expect(d.body, 'Ganz oben');
      expect(d.footnote, contains('inland'));
    });

    test('der Witz kommt als Text an', () {
      final d = TileCatalog.byKey('kopf.witz')!
          .build(const DashboardData(witz: 'Haha'), const {}, const []);
      expect(d.body, 'Haha');
    });

    test('ohne Witz steht ein Hinweis', () {
      final d = TileCatalog.byKey('kopf.witz')!
          .build(const DashboardData(), const {}, const []);
      expect(d.isEmpty, isTrue);
    });
  });

  group('Was zusätzlich geholt werden muss', () {
    // Der Grund für das Ganze: ohne diese Auskunft fragte jede Übersicht den
    // Feed ab – auch die, auf der keine einzige solche Kachel liegt.
    CustomTile kachel(String quelle) =>
        CustomTile(id: quelle, source: quelle, view: 'text');

    test('ohne solche Kacheln wird nichts geholt', () {
      expect(TileCatalog.extras([kachel('tasks.open'), kachel('kopf.quote')]),
          isEmpty);
    });

    test('eine Nachrichtenkachel meldet ihren Bedarf an', () {
      expect(TileCatalog.extras([kachel('kopf.nachrichten')]),
          {TileExtras.nachrichten});
    });

    test('zwei Kacheln derselben Quelle ergeben einen Bedarf', () {
      // Sonst würde zweimal geholt, was einmal reicht.
      expect(
        TileCatalog.extras([kachel('kopf.nachrichten'), kachel('kopf.schlagzeile')]),
        {TileExtras.nachrichten},
      );
    });

    test('Nachrichten und Witz sind zwei getrennte Bedarfe', () {
      expect(TileCatalog.extras([kachel('kopf.nachrichten'), kachel('kopf.witz')]),
          {TileExtras.nachrichten, TileExtras.witz});
    });

    test('eine unbekannte Quelle stört nicht', () {
      // Eine Kachel aus einer neueren Version darf das Laden nicht abreißen.
      expect(TileCatalog.extras([kachel('gibtsnicht')]), isEmpty);
    });
  });
}


// ── Monatsansicht ──────────────────────────────────────────────────────

void _monatsansicht() {
  PlannerEntry termin(String titel, DateTime start) => PlannerEntry(
        id: start.millisecondsSinceEpoch,
        userId: 'u',
        title: titel,
        scheduledAt: start,
        endsAt: start.add(const Duration(hours: 1)),
        createdAt: DateTime(2026),
      );

  TileData bauen(List<PlannerEntry> termine, {int versatz = 0}) =>
      TileCatalog.byKey('planner.month')!.build(
        DashboardData(plannerEntries: termine),
        {'months': versatz},
        const [],
      );

  group('Monatsansicht', () {
    final heute = DateTime.now();

    test('sie nimmt nur den gewaehlten Monat', () {
      final drin = DateTime(heute.year, heute.month, 15, 10);
      final naechster = DateTime(heute.year, heute.month + 1, 15, 10);
      final d = bauen([termin('Drin', drin), termin('Danach', naechster)]);
      expect(d.schedule.map((e) => e.title), ['Drin']);
    });

    test('der Versatz verschiebt den Monat', () {
      final naechster = DateTime(heute.year, heute.month + 1, 15, 10);
      final d = bauen([termin('Danach', naechster)], versatz: 1);
      expect(d.schedule.map((e) => e.title), ['Danach']);
    });

    test('der Anker sagt, welcher Monat gemeint ist', () {
      // Ohne ihn zeichnete die Kachel den heutigen Monat, waehrend die
      // Quelle einen versetzten liefert – das Raster bliebe leer.
      final d = bauen(const [], versatz: 2);
      final erwartet = DateTime(heute.year, heute.month + 2);
      expect(d.anker, isNotNull);
      expect(d.anker!.year, erwartet.year);
      expect(d.anker!.month, erwartet.month);
      expect(d.anker!.day, 1);
    });

    test('die Wochenansicht ankert auf ihren Montag', () {
      final d = TileCatalog.byKey('planner.week')!
          .build(const DashboardData(), const {'weeks': 1}, const []);
      expect(d.anker, isNotNull);
      expect(d.anker!.weekday, DateTime.monday);
    });

    test('Formen ohne Zeitbezug haben keinen Anker', () {
      final d = TileCatalog.byKey('tasks.open')!
          .build(const DashboardData(), const {}, const []);
      expect(d.anker, isNull);
    });

    test('die Monatsansicht nimmt Termine an, die Torte nicht', () {
      final monat = TileViews.byKey('month')!;
      expect(monat.accepts, contains(TileShape.schedule));
      expect(TileViews.byKey('pie')!.accepts, isNot(contains(TileShape.schedule)));
    });

    test('sie steht bei den Darstellungen fuer Termine zur Wahl', () {
      final passende =
          TileViews.forShape(TileShape.schedule).map((v) => v.key).toList();
      expect(passende, containsAll(['week', 'month']));
    });

    test('eine Seite ohne Terminkachel wird als solche erkannt', () {
      // Daran haengt der Hinweis im Kalenderdialog: der Filter wirkt auf
      // nichts, wenn keine Terminkachel da ist – und genau das hat
      // verwirrt, weil "Uebernehmen" dann sichtbar nichts tat.
      const ohne = [
        CustomTile(id: 'a', source: 'tasks.open', view: 'stat'),
        CustomTile(id: 'b', source: 'kopf.quote', view: 'text'),
      ];
      expect(TileCatalog.zeigtTermine(ohne), isFalse);
    });

    test('Wochen- und Monatskachel zaehlen beide als Terminkachel', () {
      for (final quelle in ['planner.week', 'planner.month']) {
        expect(
          TileCatalog.zeigtTermine(
              [CustomTile(id: 'x', source: quelle, view: 'month')]),
          isTrue,
          reason: quelle,
        );
      }
    });

    test('eine Terminliste ist keine Kalenderansicht', () {
      // planner.upcoming liefert eine Liste, keinen Zeitraum – der
      // Kalenderfilter greift dort nicht auf dieselbe Weise.
      expect(
        TileCatalog.zeigtTermine(
            [const CustomTile(id: 'x', source: 'planner.upcoming', view: 'list')]),
        isFalse,
      );
    });

    test('eine leere Seite hat keine Terminkachel', () {
      expect(TileCatalog.zeigtTermine(const []), isFalse);
    });

    test('Termine tragen die Farbe ihres Kalenders', () {
      // Sonst sieht man zwar alle ausgewaehlten Kalender, kann sie aber
      // nicht auseinanderhalten – und genau dafuer waehlt man sie aus.
      final heute = DateTime.now();
      final termin = PlannerEntry(
        id: 1, userId: 'u', title: 'Muell',
        scheduledAt: DateTime(heute.year, heute.month, 15, 8),
        endsAt: DateTime(heute.year, heute.month, 15, 9),
        createdAt: DateTime(2026),
        color: '#111111',
        calendarId: 7,
      );
      final d = TileCatalog.byKey('planner.month')!.build(
        DashboardData(
          plannerEntries: [termin],
          kalenderFarben: const {7: '#22C55E'},
        ),
        const {'months': 0},
        const [],
      );
      expect(d.schedule.single.color, '#22C55E');
    });

    test('ohne Kalenderfarbe bleibt die des Termins', () {
      // Termine aus der Zeit vor den Kalendern haben keine Zuordnung.
      final heute = DateTime.now();
      final termin = PlannerEntry(
        id: 2, userId: 'u', title: 'Alt',
        scheduledAt: DateTime(heute.year, heute.month, 16, 8),
        endsAt: DateTime(heute.year, heute.month, 16, 9),
        createdAt: DateTime(2026),
        color: '#111111',
      );
      final d = TileCatalog.byKey('planner.month')!.build(
        DashboardData(plannerEntries: [termin]),
        const {'months': 0},
        const [],
      );
      expect(d.schedule.single.color, '#111111');
    });

    test('auch die Monatsansicht kann einen Termin anlegen', () {
      expect(TileCatalog.byKey('planner.month')!.aktion?.recht, 'planner:write');
    });
  });
}

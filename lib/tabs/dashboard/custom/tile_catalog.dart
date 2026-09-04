import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/dataclasses/task.dart';
import 'package:productivity/dataclasses/time_entry.dart';
import 'package:productivity/dataclasses/pantry_extras.dart';
import 'package:productivity/dataclasses/pantry_item.dart';
import 'package:productivity/dataclasses/note.dart';
import 'package:productivity/tabs/dashboard/custom/tile_data.dart';
import 'package:productivity/main.dart';
import 'package:productivity/tabs/dashboard/custom/filter_fields.dart';
import 'package:productivity/tabs/dashboard/custom/tile_filter.dart';
import 'package:productivity/tabs/dashboard/custom/tile_spec.dart';

/// Katalog der Datenquellen.
///
/// Alle rechnen aus dem, was das Dashboard ohnehin geladen hat — kein
/// zusätzlicher Netzverkehr. Eine neue Quelle ist ein weiterer Eintrag in
/// [sources]; Oberfläche und Speicherung ziehen automatisch nach.
class TileCatalog {
  TileCatalog._();

  static const _tage = TileParam(
    key: 'days', label: 'Zeitraum in Tagen', min: 1, max: 90, standard: 7,
  );
  static const _anzahl = TileParam(
    key: 'limit', label: 'Wie viele anzeigen', min: 1, max: 20, standard: 5,
  );

  static final List<TileSource> sources = [
    // ── Termine ──────────────────────────────────────────────────────────
    TileSource(
      key: 'planner.upcoming',
      route: AppRoutes.planner,
      fields: FilterFields.termine,
      label: 'Nächste Termine',
      group: 'Planer',
      shape: TileShape.list,
      params: const [_anzahl, _tage],
      build: (d, p, f) {
        final jetzt = DateTime.now();
        final bis = jetzt.add(Duration(days: _int(p, 'days', 7)));
        final termine = applyFilters(
                d.plannerEntries.cast<PlannerEntry>(), f, FilterFields.termine)
            .where((e) =>
                e.parentId == null &&
                e.scheduledAt.isAfter(jetzt) &&
                e.scheduledAt.isBefore(bis))
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        return TileData.list(
          termine.take(_int(p, 'limit', 5)).map((e) => TileListItem(
                e.title,
                subtitle: _wann(e.scheduledAt),
              )).toList(),
          emptyHint: 'Keine Termine im Zeitraum',
        );
      },
    ),
    TileSource(
      key: 'planner.count',
      route: AppRoutes.planner,
      fields: FilterFields.termine,
      label: 'Anzahl Termine',
      group: 'Planer',
      shape: TileShape.scalar,
      params: const [_tage],
      build: (d, p, f) {
        final jetzt = DateTime.now();
        final bis = jetzt.add(Duration(days: _int(p, 'days', 7)));
        final n = applyFilters(
                d.plannerEntries.cast<PlannerEntry>(), f, FilterFields.termine)
            .where((e) =>
            e.parentId == null &&
            e.scheduledAt.isAfter(jetzt) &&
            e.scheduledAt.isBefore(bis)).length;
        return TileData.scalar(n.toDouble(), unit: 'Termine');
      },
    ),

    // ── Zeiterfassung ────────────────────────────────────────────────────
    TileSource(
      key: 'time.per_day',
      route: AppRoutes.time,
      fields: FilterFields.zeiten,
      label: 'Gestempelte Zeit je Tag',
      group: 'Zeiterfassung',
      shape: TileShape.series,
      params: const [_tage],
      build: (d, p, f) {
        final tage = _int(p, 'days', 7);
        final heute = _tagesbeginn(DateTime.now());
        final werte = <String, double>{};
        for (var i = tage - 1; i >= 0; i--) {
          final tag = heute.subtract(Duration(days: i));
          werte[_kurzTag(tag)] = 0;
        }
        for (final e in applyFilters(
            d.timeEntries.cast<TimeEntry>(), f, FilterFields.zeiten)) {
          if (e.endTime == null) continue;
          final tag = _tagesbeginn(e.startTime);
          if (tag.isBefore(heute.subtract(Duration(days: tage - 1)))) continue;
          if (tag.isAfter(heute)) continue;
          final label = _kurzTag(tag);
          final stunden = e.endTime!.difference(e.startTime).inMinutes / 60.0;
          werte[label] = (werte[label] ?? 0) + stunden;
        }
        return TileData.series(werte, unit: 'h', emptyHint: 'Nichts gestempelt');
      },
    ),
    TileSource(
      key: 'time.total',
      route: AppRoutes.time,
      fields: FilterFields.zeiten,
      label: 'Gestempelte Zeit gesamt',
      group: 'Zeiterfassung',
      shape: TileShape.scalar,
      params: const [_tage],
      build: (d, p, f) {
        final tage = _int(p, 'days', 7);
        final ab = _tagesbeginn(DateTime.now()).subtract(Duration(days: tage - 1));
        var minuten = 0;
        for (final e in applyFilters(
            d.timeEntries.cast<TimeEntry>(), f, FilterFields.zeiten)) {
          if (e.endTime == null) continue;
          if (e.startTime.isBefore(ab)) continue;
          minuten += e.endTime!.difference(e.startTime).inMinutes;
        }
        return TileData.scalar(minuten / 60.0, unit: 'h');
      },
    ),

    // ── Aufgaben ─────────────────────────────────────────────────────────
    TileSource(
      key: 'tasks.open',
      route: AppRoutes.tasks,
      fields: FilterFields.aufgaben,
      label: 'Offene Aufgaben',
      group: 'Aufgaben',
      shape: TileShape.scalar,
      build: (d, p, f) => TileData.scalar(
        applyFilters(d.tasks.cast<Task>(), f, FilterFields.aufgaben)
            .where((t) => !t.completed)
            .length
            .toDouble(),
        unit: 'offen',
      ),
    ),
    TileSource(
      key: 'tasks.due',
      route: AppRoutes.tasks,
      fields: FilterFields.aufgaben,
      label: 'Bald fällige Aufgaben',
      group: 'Aufgaben',
      shape: TileShape.list,
      params: const [_anzahl, _tage],
      build: (d, p, f) {
        final bis = _tagesbeginn(DateTime.now())
            .add(Duration(days: _int(p, 'days', 7)));
        final faellig = applyFilters(
                d.tasks.cast<Task>(), f, FilterFields.aufgaben)
            .where((t) =>
                !t.completed && t.dueDate != null && t.dueDate!.isBefore(bis))
            .toList()
          ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
        return TileData.list(
          faellig.take(_int(p, 'limit', 5)).map((t) => TileListItem(
                t.title,
                subtitle: _datum(t.dueDate!),
              )).toList(),
          emptyHint: 'Nichts fällig',
        );
      },
    ),
    TileSource(
      key: 'tasks.by_state',
      route: AppRoutes.tasks,
      fields: FilterFields.aufgaben,
      label: 'Aufgaben je Spalte',
      group: 'Aufgaben',
      shape: TileShape.distribution,
      build: (d, p, f) {
        final zaehler = <String, double>{};
        for (final t in applyFilters(
            d.tasks.cast<Task>(), f, FilterFields.aufgaben)) {
          final s = t.kanbanState;
          zaehler[s] = (zaehler[s] ?? 0) + 1;
        }
        return TileData.distribution(zaehler, emptyHint: 'Keine Aufgaben');
      },
    ),

    TileSource(
      key: 'tasks.by_priority',
      route: AppRoutes.tasks,
      fields: FilterFields.aufgaben,
      label: 'Aufgaben je Priorität',
      group: 'Aufgaben',
      shape: TileShape.distribution,
      build: (d, p, f) {
        const namen = {'low': 'Niedrig', 'medium': 'Mittel', 'high': 'Hoch'};
        final zaehler = <String, double>{};
        for (final t in applyFilters(
            d.tasks.cast<Task>(), f, FilterFields.aufgaben)) {
          final k = namen[t.priority] ?? t.priority;
          zaehler[k] = (zaehler[k] ?? 0) + 1;
        }
        return TileData.distribution(zaehler, emptyHint: 'Keine Aufgaben');
      },
    ),
    TileSource(
      key: 'tasks.by_category',
      route: AppRoutes.tasks,
      fields: FilterFields.aufgaben,
      label: 'Aufgaben je Kategorie',
      group: 'Aufgaben',
      shape: TileShape.distribution,
      build: (d, p, f) {
        final zaehler = <String, double>{};
        for (final t in applyFilters(
            d.tasks.cast<Task>(), f, FilterFields.aufgaben)) {
          final k = (t.category?.isNotEmpty == true) ? t.category! : 'Ohne';
          zaehler[k] = (zaehler[k] ?? 0) + 1;
        }
        return TileData.distribution(zaehler, emptyHint: 'Keine Aufgaben');
      },
    ),

    // ── Zeiterfassung: Verteilungen ──────────────────────────────────────
    TileSource(
      key: 'time.by_description',
      route: AppRoutes.time,
      fields: FilterFields.zeiten,
      label: 'Zeit je Tätigkeit',
      group: 'Zeiterfassung',
      shape: TileShape.distribution,
      params: const [_tage],
      build: (d, p, f) {
        final tage = _int(p, 'days', 7);
        final ab = _tagesbeginn(DateTime.now())
            .subtract(Duration(days: tage - 1));
        final zaehler = <String, double>{};
        for (final e in applyFilters(
            d.timeEntries.cast<TimeEntry>(), f, FilterFields.zeiten)) {
          if (e.endTime == null) continue;
          if (e.startTime.isBefore(ab)) continue;
          final name = e.description.trim().isNotEmpty
              ? e.description.trim()
              : 'Ohne Beschreibung';
          final stunden = e.endTime!.difference(e.startTime).inMinutes / 60.0;
          zaehler[name] = (zaehler[name] ?? 0) + stunden;
        }
        // Nur die groessten sieben, der Rest zusammengefasst – ein
        // Tortendiagramm mit dreissig Stuecken liest niemand.
        return TileData.distribution(_grosseZuerst(zaehler, 7),
            unit: 'h', emptyHint: 'Keine Zeiten');
      },
    ),

    // ── Planer: Verteilung und Verlauf ───────────────────────────────────
    TileSource(
      key: 'planner.by_type',
      route: AppRoutes.planner,
      fields: FilterFields.termine,
      label: 'Termine je Typ',
      group: 'Planer',
      shape: TileShape.distribution,
      params: const [_tage],
      build: (d, p, f) {
        final jetzt = DateTime.now();
        final bis = jetzt.add(Duration(days: _int(p, 'days', 7)));
        final zaehler = <String, double>{};
        for (final e in applyFilters(
            d.plannerEntries.cast<PlannerEntry>(), f, FilterFields.termine)) {
          if (e.parentId != null) continue;
          if (e.scheduledAt.isBefore(jetzt) || e.scheduledAt.isAfter(bis)) {
            continue;
          }
          final k = (e.type?.isNotEmpty == true) ? e.type! : 'Ohne Typ';
          zaehler[k] = (zaehler[k] ?? 0) + 1;
        }
        return TileData.distribution(zaehler, emptyHint: 'Keine Termine');
      },
    ),
    TileSource(
      key: 'planner.per_day',
      route: AppRoutes.planner,
      fields: FilterFields.termine,
      label: 'Termine je Tag',
      group: 'Planer',
      shape: TileShape.series,
      params: const [_tage],
      build: (d, p, f) {
        final tage = _int(p, 'days', 7);
        final heute = _tagesbeginn(DateTime.now());
        final punkte = <String, double>{};
        for (var i = 0; i < tage; i++) {
          punkte[_kurzTag(heute.add(Duration(days: i)))] = 0;
        }
        for (final e in applyFilters(
            d.plannerEntries.cast<PlannerEntry>(), f, FilterFields.termine)) {
          if (e.parentId != null) continue;
          final k = _kurzTag(_tagesbeginn(e.scheduledAt));
          if (punkte.containsKey(k)) punkte[k] = punkte[k]! + 1;
        }
        return TileData.series(punkte, emptyHint: 'Keine Termine');
      },
    ),

    // ── Einkauf und Vorrat ───────────────────────────────────────────────
    TileSource(
      key: 'shopping.open',
      route: AppRoutes.shoppingList,
      fields: FilterFields.einkauf,
      label: 'Offene Einkaufsposten',
      group: 'Einkauf',
      shape: TileShape.scalar,
      build: (d, p, f) => TileData.scalar(
        applyFilters(d.shoppingItems.cast<ShoppingListItem>(), f,
                FilterFields.einkauf)
            .where((i) => !i.isBought)
            .length
            .toDouble(),
        unit: 'Posten',
      ),
    ),
    TileSource(
      key: 'pantry.low',
      route: AppRoutes.pantry,
      fields: FilterFields.vorrat,
      label: 'Knappe Vorräte',
      group: 'Vorrat',
      shape: TileShape.list,
      params: const [_anzahl],
      build: (d, p, f) {
        final knapp = applyFilters(
                d.pantryItems.cast<PantryItem>(), f, FilterFields.vorrat)
            .where((i) => i.amount <= i.minAmount)
            .toList();
        return TileData.list(
          knapp.take(_int(p, 'limit', 5)).map((i) {
            final zutat = d.ingredientMap[i.ingredientId];
            return TileListItem(
              zutat == null ? 'Unbekannt' : '${zutat.name}',
              subtitle: 'Bestand ${_zahl(i.amount)}',
            );
          }).toList(),
          emptyHint: 'Alles ausreichend da',
        );
      },
    ),

    // ── Notizen ──────────────────────────────────────────────────────────
    TileSource(
      key: 'notes.recent',
      route: AppRoutes.notes,
      fields: FilterFields.notizen,
      label: 'Zuletzt geänderte Notizen',
      group: 'Notizen',
      shape: TileShape.list,
      params: const [_anzahl],
      build: (d, p, f) {
        DateTime stand(Note n) => n.updatedAt ?? n.createdAt;
        final notizen =
            applyFilters(d.notes.cast<Note>(), f, FilterFields.notizen).toList()
          ..sort((a, b) => stand(b).compareTo(stand(a)));
        return TileData.list(
          notizen.take(_int(p, 'limit', 5)).map((n) => TileListItem(
                n.title.isEmpty ? 'Ohne Titel' : n.title,
                subtitle: _datum(stand(n)),
              )).toList(),
          emptyHint: 'Keine Notizen',
        );
      },
    ),
  ];

  static TileSource? byKey(String key) {
    for (final s in sources) {
      if (s.key == key) return s;
    }
    return null;
  }

  /// Quellen nach Bereich gruppiert – für die Auswahl beim Anlegen.
  static Map<String, List<TileSource>> get grouped {
    final map = <String, List<TileSource>>{};
    for (final s in sources) {
      map.putIfAbsent(s.group, () => []).add(s);
    }
    return map;
  }

  // ── Hilfen ─────────────────────────────────────────────────────────────
  static int _int(Map<String, dynamic> p, String key, int fallback) {
    final v = p[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }

  static DateTime _tagesbeginn(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _kurzTag(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

  static String _datum(DateTime d) => _kurzTag(d);

  static String _wann(DateTime d) {
    final heute = _tagesbeginn(DateTime.now());
    final tag = _tagesbeginn(d);
    final uhr =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final diff = tag.difference(heute).inDays;
    if (diff == 0) return 'Heute $uhr';
    if (diff == 1) return 'Morgen $uhr';
    return '${_kurzTag(d)} $uhr';
  }

  static String _zahl(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
}

/// Die groessten Eintraege zuerst, der lange Schwanz als "Sonstige".
///
/// Ohne das wird ein Tortendiagramm mit vielen kleinen Kategorien
/// unleserlich – und die Legende laenger als das Diagramm.
Map<String, double> _grosseZuerst(Map<String, double> werte, int wieViele) {
  final sortiert = werte.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (sortiert.length <= wieViele) {
    return {for (final e in sortiert) e.key: e.value};
  }
  final ergebnis = <String, double>{
    for (final e in sortiert.take(wieViele)) e.key: e.value
  };
  final rest = sortiert.skip(wieViele).fold<double>(0, (a, e) => a + e.value);
  if (rest > 0) ergebnis['Sonstige'] = rest;
  return ergebnis;
}

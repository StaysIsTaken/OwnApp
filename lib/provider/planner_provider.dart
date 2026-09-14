import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/kalender.dart';
import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/dataclasses/planner_entry_type.dart';
import 'package:productivity/dataservice/planner_notification_scheduler.dart';
import 'package:productivity/dataservice/calendar_service.dart';
import 'package:productivity/dataservice/planner_service.dart';

class PlannerProvider extends ChangeNotifier {
  List<PlannerEntry> _entries = [];
  List<PlannerEntryType> _types = [];
  List<Kalender> _kalender = [];
  Set<int>? _sichtbareKalender;
  bool _isLoading = false;
  String? _error;

  List<PlannerEntry> get entries => _entries;
  List<PlannerEntryType> get types => _types;
  List<Kalender> get kalender => _kalender;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Welche Kalender die Ansicht zeigt — `null` heißt alle.
  ///
  /// Bewusst `null` und nicht „die Menge aller IDs": ein neu angelegter
  /// Kalender soll sofort mitlaufen und nicht stillschweigend ausgeblendet
  /// sein, nur weil er beim Setzen des Filters noch nicht existierte.
  Set<int>? get sichtbareKalender =>
      _sichtbareKalender == null ? null : Set.unmodifiable(_sichtbareKalender!);

  bool get filterAktiv => _sichtbareKalender != null;

  /// Die Namen der gerade gezeigten Kalender — für die Sprachantwort.
  List<String> get sichtbareNamen {
    final ids = _sichtbareKalender;
    if (ids == null) return _kalender.map((k) => k.name).toList();
    return _kalender.where((k) => ids.contains(k.id)).map((k) => k.name).toList();
  }

  /// Zeigt nur noch die angegebenen Kalender. `null` oder leer hebt den
  /// Filter auf — „zeige wieder alle Kalender an".
  void zeigeNur(Set<int>? ids) {
    _sichtbareKalender = (ids == null || ids.isEmpty) ? null : {...ids};
    notifyListeners();
  }

  /// [alle] holt auch die Kalender der übrigen Personen — das braucht das
  /// Küchen-Tablet, damit „zeige nur Lisas Kalender an" etwas findet.
  ///
  /// Fehlt dafür das Recht, antwortet der Server mit 403. Dann lieber die
  /// eigenen Kalender als gar keine: ein Filter, der nichts zur Auswahl hat,
  /// ist schlimmer als einer mit weniger Auswahl.
  Future<void> loadKalender({bool alle = false}) async {
    try {
      try {
        _kalender = await CalendarService.laden(alle: alle);
      } catch (e) {
        if (!alle) rethrow;
        _kalender = await CalendarService.laden();
      }
      // Ein Kalender, der nicht mehr da ist, darf keinen Filter am Leben
      // halten, der nichts mehr durchlässt.
      final ids = _sichtbareKalender;
      if (ids != null) {
        final bekannt = _kalender.map((k) => k.id).toSet();
        final rest = ids.intersection(bekannt);
        _sichtbareKalender = rest.isEmpty ? null : rest;
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  /// Der Filter, angewandt auf einen einzelnen Termin.
  ///
  /// Termine ohne Kalender verschwinden, sobald gefiltert wird. „Nur der
  /// Arbeitskalender" heißt nur der Arbeitskalender; ein Termin, der in
  /// keinem liegt, gehört nicht dazu. Ohne Filter sind sie natürlich da.
  @visibleForTesting
  static bool sichtbar(PlannerEntry e, Set<int>? sichtbareKalender) {
    if (sichtbareKalender == null) return true;
    final id = e.calendarId;
    return id != null && sichtbareKalender.contains(id);
  }

  bool _sichtbar(PlannerEntry e) => sichtbar(e, _sichtbareKalender);

  /// Erinnerungen für einen einzelnen Termin auffrischen.
  ///
  /// Beim vollständigen Laden übernimmt der `NotificationScheduler` das
  /// gemeinsam mit den Aufgaben (wegen des iOS-Limits von 64); für einzelne
  /// Änderungen genügt der direkte Weg.
  Future<void> _syncEntryNotification(PlannerEntry entry) async {
    try {
      await PlannerNotificationScheduler.schedule(entry);
    } catch (_) {
      // Erinnerungen sind Beiwerk – ein Fehler hier darf das Speichern
      // des Termins nicht scheitern lassen.
    }
  }

  Future<void> loadEntries() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _entries = await PlannerService.loadAll();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Termine ohne Netz setzen — nur fuer Tests.
  ///
  /// Ohne diese Naht liesse sich der Kalenderfilter nur an der reinen
  /// Rechnung [sichtbar] pruefen, nicht daran, ob er in den drei Abfragen
  /// ueberhaupt angewandt wird. Genau dort sass der Fehler, den man sucht.
  @visibleForTesting
  void setzeTermine(List<PlannerEntry> termine) {
    _entries = [...termine];
    notifyListeners();
  }

  /// Den Ladezustand von Hand setzen — nur fuer Tests.
  ///
  /// Ohne diese Naht liesse sich nicht pruefen, was beim Laden mit der
  /// Oberflaeche geschieht: der Consumer tauscht das Raster gegen einen
  /// Fortschrittskreis, und dabei verschwindet die Scroll-Ansicht samt
  /// ihrer Position aus dem Baum. Genau dort sass ein Fehler, den man
  /// sonst nur auf dem Geraet sieht — `loadEntries()` selbst braucht einen
  /// Server und wartet im Test minutenlang ins Leere.
  @visibleForTesting
  void setzeLadend(bool laedt) {
    _isLoading = laedt;
    notifyListeners();
  }

  @visibleForTesting
  void setzeKalender(List<Kalender> kalender) {
    _kalender = [...kalender];
    notifyListeners();
  }

  Future<void> createEntry({
    required String title,
    String? description,
    required int typeId,
    required DateTime scheduledAt,
    required DateTime endsAt,
    int notifyMinBefore = 10,
    String color = '#3B82F6',
    int? parentId,
    int orderIndex = 0,
    List<String>? participantIds,
    int? calendarId,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final newEntry = await PlannerService.create(
        title: title,
        description: description,
        typeId: typeId,
        scheduledAt: scheduledAt,
        endsAt: endsAt,
        notifyMinBefore: notifyMinBefore,
        color: color,
        parentId: parentId,
        orderIndex: orderIndex,
        participantIds: participantIds,
        // Ohne Angabe entscheidet das Backend (Standardkalender).
        calendarId: calendarId,
      );

      _entries.add(newEntry);
      await _syncEntryNotification(newEntry);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateEntry(
    int id, {
    String? title,
    String? description,
    int? typeId,
    DateTime? scheduledAt,
    DateTime? endsAt,
    int? durationMin,
    int? notifyMinBefore,
    String? color,
    int? parentId,
    int? orderIndex,
    bool? notified,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final updated = await PlannerService.update(
        id,
        title: title,
        description: description,
        typeId: typeId,
        scheduledAt: scheduledAt,
        endsAt: endsAt,
        durationMin: durationMin,
        notifyMinBefore: notifyMinBefore,
        color: color,
        parentId: parentId,
        orderIndex: orderIndex,
        notified: notified,
      );

      final index = _entries.indexWhere((e) => e.id == id);
      if (index >= 0) {
        _entries[index] = updated;
        await _syncEntryNotification(updated);
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── iCal-Import ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> importIcs({
    required int typeId,
    String? url,
    String? ics,
    String color = '#3B82F6',
  }) async {
    final result = await PlannerService.importIcs(
      typeId: typeId,
      url: url,
      ics: ics,
      color: color,
    );
    await loadEntries();
    return result;
  }

  // ── Wiederkehrende Serien ──────────────────────────────────────────────

  Future<void> createRecurringEntry({
    required String title,
    String? description,
    required int typeId,
    required DateTime scheduledAt,
    required DateTime endsAt,
    int notifyMinBefore = 10,
    String color = '#3B82F6',
    required Map<String, dynamic> recurrence,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await PlannerService.createRecurring(
        title: title,
        description: description,
        typeId: typeId,
        scheduledAt: scheduledAt,
        endsAt: endsAt,
        notifyMinBefore: notifyMinBefore,
        color: color,
        recurrence: recurrence,
      );
      await loadEntries();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// scope: 'single' | 'all' | 'future'
  Future<void> updateSeriesEntry(
    int id,
    String scope, {
    String? title,
    String? description,
    int? typeId,
    DateTime? scheduledAt,
    DateTime? endsAt,
    int? notifyMinBefore,
    String? color,
  }) async {
    try {
      await PlannerService.updateSeries(
        id,
        scope,
        title: title,
        description: description,
        typeId: typeId,
        scheduledAt: scheduledAt,
        endsAt: endsAt,
        notifyMinBefore: notifyMinBefore,
        color: color,
      );
      await loadEntries();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// scope: 'single' | 'all' | 'future'
  Future<void> deleteSeriesEntry(int id, String scope) async {
    try {
      await PlannerService.deleteSeries(id, scope);
      await loadEntries();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Legt eine Unteraufgabe (Child-Eintrag) unter [parentId] an und lädt neu,
  /// damit die verschachtelten Children aktuell sind.
  Future<void> createSubtask({
    required int parentId,
    required String title,
    String? description,
    required int typeId,
    required DateTime scheduledAt,
    required DateTime endsAt,
    String color = '#3B82F6',
    int orderIndex = 0,
  }) async {
    try {
      await PlannerService.create(
        title: title,
        description: description,
        typeId: typeId,
        scheduledAt: scheduledAt,
        endsAt: endsAt,
        color: color,
        parentId: parentId,
        orderIndex: orderIndex,
      );
      await loadEntries();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Löscht einen Child-Eintrag und lädt neu (Children stehen nicht in der
  /// Top-Level-Liste, daher Reload statt lokalem Entfernen).
  Future<void> deleteChildEntry(int id) async {
    try {
      await PlannerService.delete(id);
      await loadEntries();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteEntry(int id) async {
    _isLoading = true;
    notifyListeners();

    try {
      await PlannerService.delete(id);
      _entries.removeWhere((e) => e.id == id);
      await PlannerNotificationScheduler.cancel(id);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Verschiebt einen Eintrag (Drag & Drop). Aktualisiert sofort lokal
  /// (optimistisch, ohne Lade-Spinner) und persistiert im Hintergrund.
  Future<void> moveEntry(
    int id, {
    required DateTime scheduledAt,
    required DateTime endsAt,
  }) async {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index < 0) return;

    final original = _entries[index];
    final durationMin = endsAt.difference(scheduledAt).inMinutes;

    _entries[index] = original.copyWith(
      scheduledAt: scheduledAt,
      endsAt: endsAt,
      durationMin: durationMin < 1 ? 1 : durationMin,
      isDetached: original.recurrenceId != null ? true : null,
    );
    notifyListeners();

    try {
      if (original.recurrenceId != null) {
        // Serien-Termin per Drag = nur dieses Vorkommen lösen (detach)
        await PlannerService.updateSeries(
          id,
          'single',
          scheduledAt: scheduledAt,
          endsAt: endsAt,
        );
      } else {
        final updated = await PlannerService.update(
          id,
          scheduledAt: scheduledAt,
          endsAt: endsAt,
        );
        final i = _entries.indexWhere((e) => e.id == id);
        if (i >= 0) _entries[i] = updated;
      }
      _error = null;
    } catch (e) {
      // Bei Fehler zurückrollen
      final i = _entries.indexWhere((e) => e.id == id);
      if (i >= 0) _entries[i] = original;
      _error = e.toString();
    }
    notifyListeners();
  }

  // ── Stammdaten: Typen ──────────────────────────────────────────────────

  Future<void> loadTypes() async {
    try {
      _types = await PlannerService.loadTypes();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> createType({
    required String name,
    String color = '#3B82F6',
    String? icon,
  }) async {
    final created = await PlannerService.createType(
      name: name,
      color: color,
      icon: icon,
      orderIndex: _types.length,
    );
    _types.add(created);
    notifyListeners();
  }

  Future<void> updateType(
    int id, {
    String? name,
    String? color,
    String? icon,
  }) async {
    final updated = await PlannerService.updateType(
      id,
      name: name,
      color: color,
      icon: icon,
    );
    final index = _types.indexWhere((t) => t.id == id);
    if (index >= 0) _types[index] = updated;
    notifyListeners();
  }

  Future<void> deletePlannerType(int id) async {
    await PlannerService.deleteType(id);
    _types.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  List<PlannerEntry> getEntriesForDay(DateTime date) {
    return _entries
        .where((e) =>
            _isSameDay(e.scheduledAt, date) &&
            e.parentId == null &&
            _sichtbar(e))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  List<PlannerEntry> getEntriesForWeek(DateTime weekStart) {
    final weekEnd = weekStart.add(Duration(days: 7));
    // Inkl. Sub-Einträge (Children) – sie werden in der Wochenansicht angezeigt.
    return _entries
        .where((e) =>
            !e.scheduledAt.isBefore(weekStart) &&
            e.scheduledAt.isBefore(weekEnd) &&
            _sichtbar(e))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  List<PlannerEntry> getEntriesForMonth(DateTime monthDate) {
    return _entries
        .where((e) =>
            e.scheduledAt.year == monthDate.year &&
            e.scheduledAt.month == monthDate.month &&
            e.parentId == null &&
            _sichtbar(e))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  List<PlannerEntry> getChildEntries(int parentId) {
    return _entries
        .where((e) => e.parentId == parentId)
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

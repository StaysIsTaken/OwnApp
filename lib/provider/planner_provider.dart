import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/dataclasses/planner_entry_type.dart';
import 'package:productivity/dataservice/planner_service.dart';

class PlannerProvider extends ChangeNotifier {
  List<PlannerEntry> _entries = [];
  List<PlannerEntryType> _types = [];
  bool _isLoading = false;
  String? _error;

  List<PlannerEntry> get entries => _entries;
  List<PlannerEntryType> get types => _types;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
      );

      _entries.add(newEntry);
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
    String color = '#3B82F6',
  }) async {
    final result = await PlannerService.importIcs(
      typeId: typeId,
      url: url,
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
        .where((e) => _isSameDay(e.scheduledAt, date) && e.parentId == null)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  List<PlannerEntry> getEntriesForWeek(DateTime weekStart) {
    final weekEnd = weekStart.add(Duration(days: 7));
    // Inkl. Sub-Einträge (Children) – sie werden in der Wochenansicht angezeigt.
    return _entries
        .where((e) =>
            !e.scheduledAt.isBefore(weekStart) &&
            e.scheduledAt.isBefore(weekEnd))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  List<PlannerEntry> getEntriesForMonth(DateTime monthDate) {
    return _entries
        .where((e) =>
            e.scheduledAt.year == monthDate.year &&
            e.scheduledAt.month == monthDate.month &&
            e.parentId == null)
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

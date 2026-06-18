import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/dataservice/planner_service.dart';

class PlannerProvider extends ChangeNotifier {
  List<PlannerEntry> _entries = [];
  bool _isLoading = false;
  String? _error;

  List<PlannerEntry> get entries => _entries;
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
    required String type,
    required DateTime scheduledAt,
    int durationMin = 60,
    int notifyMinBefore = 10,
    String color = '#3B82F6',
    int? parentId,
    int orderIndex = 0,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final newEntry = await PlannerService.create(
        title: title,
        description: description,
        type: type,
        scheduledAt: scheduledAt,
        durationMin: durationMin,
        notifyMinBefore: notifyMinBefore,
        color: color,
        parentId: parentId,
        orderIndex: orderIndex,
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
    String? type,
    DateTime? scheduledAt,
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
        type: type,
        scheduledAt: scheduledAt,
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

  List<PlannerEntry> getEntriesForDay(DateTime date) {
    return _entries
        .where((e) => _isSameDay(e.scheduledAt, date) && e.parentId == null)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  List<PlannerEntry> getEntriesForWeek(DateTime weekStart) {
    final weekEnd = weekStart.add(Duration(days: 7));
    return _entries
        .where((e) =>
            !e.scheduledAt.isBefore(weekStart) &&
            e.scheduledAt.isBefore(weekEnd) &&
            e.parentId == null)
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

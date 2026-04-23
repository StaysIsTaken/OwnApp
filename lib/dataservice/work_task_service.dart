import 'package:shared_preferences/shared_preferences.dart';
import 'package:productivity/models/work_task.dart';

// ─────────────────────────────────────────────
//  WorkTaskService
//  Persists WorkTask objects via SharedPreferences.
// ─────────────────────────────────────────────
class WorkTaskService {
  WorkTaskService._();

  static const String _key = 'work_tasks';

  /// Returns all tasks, unsorted.
  static Future<List<WorkTask>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.map(WorkTask.fromJsonString).toList();
  }

  /// Adds a new task to persistent storage.
  static Future<void> save(WorkTask task) async {
    final tasks = await loadAll();
    tasks.add(task);
    await _persist(tasks);
  }

  /// Removes the task with the given [id].
  static Future<void> delete(String id) async {
    final tasks = await loadAll();
    tasks.removeWhere((t) => t.id == id);
    await _persist(tasks);
  }

  static Future<void> _persist(List<WorkTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      tasks.map((t) => t.toJsonString()).toList(),
    );
  }
}

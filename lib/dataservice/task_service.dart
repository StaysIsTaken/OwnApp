import 'package:productivity/dataclasses/task.dart';
import 'package:productivity/dataservice/api_client.dart';
import 'package:productivity/dataservice/task_notification_scheduler.dart';

class TaskService {
  TaskService._();

  static const String _path = '/tasks';

  static Future<List<Task>> loadAll({
    int skip = 0,
    int limit = 100,
    bool? completed,
    String? category,
  }) async {
    final response = await ApiClient.dio.get(
      _path,
      queryParameters: {
        'skip': skip,
        'limit': limit,
        'completed': ?completed,
        'category': ?category,
      },
    );

    final listRaw = response.data is Map
        ? response.data['items'] ?? []
        : response.data;
    return (listRaw as List)
        .map((item) => Task.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Task>> loadPending() async {
    final response = await ApiClient.dio.get('$_path/pending');
    return (response.data as List)
        .map((item) => Task.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<Task> getTask(String taskId) async {
    final response = await ApiClient.dio.get('$_path/$taskId');
    return Task.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Task> create(Task task) async {
    final payload = {
      'title': task.title,
      if (task.description != null) 'description': task.description,
      if (task.dueDate != null)
        'dueDate': task.dueDate!.toIso8601String().split('T')[0],
      if (task.category != null) 'category': task.category,
      'priority': task.priority,
    };

    final response = await ApiClient.dio.post(_path, data: payload);
    final created = Task.fromJson(response.data as Map<String, dynamic>);
    // Schedule local reminders for the new task
    await TaskNotificationScheduler.schedule(created);
    return created;
  }

  static Future<Task> update(Task task) async {
    final payload = {
      'title': task.title,
      if (task.description != null) 'description': task.description,
      if (task.dueDate != null)
        'dueDate': task.dueDate!.toIso8601String().split('T')[0],
      'completed': task.completed,
      if (task.category != null) 'category': task.category,
      'priority': task.priority,
      'kanbanState': task.kanbanState,
    };

    final response = await ApiClient.dio.put(
      '$_path/${task.id}',
      data: payload,
    );
    final updated = Task.fromJson(response.data as Map<String, dynamic>);
    // Re-schedule (or cancel, if completed/no due date) reminders
    await TaskNotificationScheduler.schedule(updated);
    return updated;
  }

  static Future<void> delete(String taskId) async {
    await ApiClient.dio.delete('$_path/$taskId');
    // Cancel any pending reminders for this task
    await TaskNotificationScheduler.cancel(taskId);
  }

  static Future<Task> toggleCompleted(String taskId, String kanbanState) async {
    final response = await ApiClient.dio.patch(
      '$_path/$taskId/toggle',
      data: {'kanbanState': kanbanState},
    );
    final updated = Task.fromJson(response.data as Map<String, dynamic>);
    // If task is now completed, cancel reminders; if uncompleted, re-schedule
    await TaskNotificationScheduler.schedule(updated);
    return updated;
  }
}

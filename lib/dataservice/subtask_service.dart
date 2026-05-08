import 'package:productivity/dataclasses/subtask.dart';
import 'package:productivity/dataservice/api_client.dart';

class SubTaskService {
  SubTaskService._();

  static const String _path = '/subtasks';

  static Future<List<SubTask>> loadByTaskId(String taskId) async {
    final response = await ApiClient.dio.get(
      _path,
      queryParameters: {'taskId': taskId},
    );

    final listRaw = response.data is Map ? response.data['items'] ?? [] : response.data;
    return (listRaw as List)
        .map((item) => SubTask.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<SubTask> create(SubTask subtask) async {
    final payload = {
      'taskId': subtask.taskId,
      'title': subtask.title,
      if (subtask.description != null) 'description': subtask.description,
      if (subtask.dueDate != null) 'dueDate': subtask.dueDate!.toIso8601String().split('T')[0],
      if (subtask.category != null) 'category': subtask.category,
      'priority': subtask.priority,
    };

    final response = await ApiClient.dio.post(_path, data: payload);
    return SubTask.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<SubTask> update(SubTask subtask) async {
    final payload = {
      'title': subtask.title,
      if (subtask.description != null) 'description': subtask.description,
      if (subtask.dueDate != null) 'dueDate': subtask.dueDate!.toIso8601String().split('T')[0],
      'completed': subtask.completed,
      if (subtask.category != null) 'category': subtask.category,
      'priority': subtask.priority,
    };

    final response = await ApiClient.dio.put('$_path/${subtask.id}', data: payload);
    return SubTask.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> delete(String subtaskId) async {
    await ApiClient.dio.delete('$_path/$subtaskId');
  }

  static Future<SubTask> toggleCompleted(String subtaskId) async {
    final response = await ApiClient.dio.patch(
      '$_path/$subtaskId/toggle',
    );
    return SubTask.fromJson(response.data as Map<String, dynamic>);
  }
}

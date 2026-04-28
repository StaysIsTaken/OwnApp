import 'package:productivity/dataclasses/time_entry.dart';
import 'package:productivity/dataservice/api_client.dart';

// ─────────────────────────────────────────────
//  TimeEntryService – API-backed
//  Replaces the old work_task_service.dart
// ─────────────────────────────────────────────
class TimeEntryService {
  TimeEntryService._();

  static const String _path = '/timeentries';

  static Future<List<TimeEntry>> loadAll() async {
    final response = await ApiClient.dio.get(_path);
    final data = response.data;
    final List<dynamic> listRaw = data is Map ? data['items'] ?? [] : data;
    
    return listRaw
        .map((e) => TimeEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<TimeEntry> create(TimeEntry entry) async {
    final response = await ApiClient.dio.post(_path, data: entry.toJson());
    return TimeEntry.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<TimeEntry> update(TimeEntry entry) async {
    final response = await ApiClient.dio.put(
      '$_path/${entry.id}',
      data: entry.toJson(),
    );
    return TimeEntry.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> delete(String id) async {
    await ApiClient.dio.delete('$_path/$id');
  }
}

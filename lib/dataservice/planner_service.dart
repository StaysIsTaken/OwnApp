import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/dataservice/api_client.dart';

class PlannerService {
  PlannerService._();
  static const String _path = '/planner';

  static Future<List<PlannerEntry>> loadAll() async {
    try {
      final response = await ApiClient.dio.get(_path);
      if (response.statusCode == 200) {
        final List<dynamic> items = response.data is List ? response.data : [];
        return items
            .map((item) => PlannerEntry.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Fehler beim Laden der Planner-Einträge: $e');
    }
  }

  static Future<PlannerEntry> getById(int id) async {
    try {
      final response = await ApiClient.dio.get('$_path/$id');
      return PlannerEntry.fromJson(response.data);
    } catch (e) {
      throw Exception('Fehler beim Laden des Eintrags: $e');
    }
  }

  static Future<PlannerEntry> create({
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
    try {
      final response = await ApiClient.dio.post(_path, data: {
        'title': title,
        'description': description,
        'type': type,
        'scheduled_at': scheduledAt.toIso8601String(),
        'duration_min': durationMin,
        'notify_min_before': notifyMinBefore,
        'color': color,
        'parent_id': parentId,
        'order_index': orderIndex,
      });

      if (response.statusCode == 200) {
        return PlannerEntry.fromJson(response.data);
      }
      throw Exception('Fehler beim Erstellen des Eintrags');
    } catch (e) {
      throw Exception('Fehler beim Erstellen des Eintrags: $e');
    }
  }

  static Future<PlannerEntry> update(
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
    try {
      final Map<String, dynamic> data = {};
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (type != null) data['type'] = type;
      if (scheduledAt != null) data['scheduled_at'] = scheduledAt.toIso8601String();
      if (durationMin != null) data['duration_min'] = durationMin;
      if (notifyMinBefore != null) data['notify_min_before'] = notifyMinBefore;
      if (color != null) data['color'] = color;
      if (parentId != null) data['parent_id'] = parentId;
      if (orderIndex != null) data['order_index'] = orderIndex;
      if (notified != null) data['notified'] = notified;

      final response = await ApiClient.dio.put('$_path/$id', data: data);

      if (response.statusCode == 200) {
        return PlannerEntry.fromJson(response.data);
      }
      throw Exception('Fehler beim Aktualisieren des Eintrags');
    } catch (e) {
      throw Exception('Fehler beim Aktualisieren des Eintrags: $e');
    }
  }

  static Future<void> delete(int id) async {
    try {
      final response = await ApiClient.dio.delete('$_path/$id');
      if (response.statusCode != 200) {
        throw Exception('Fehler beim Löschen des Eintrags');
      }
    } catch (e) {
      throw Exception('Fehler beim Löschen des Eintrags: $e');
    }
  }

  static Future<List<PlannerEntry>> getPendingNotifications() async {
    try {
      final response = await ApiClient.dio.get('$_path/pending/notifications');
      if (response.statusCode == 200) {
        final List<dynamic> items = response.data is List ? response.data : [];
        return items
            .map((item) => PlannerEntry.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Fehler beim Laden der ausstehenden Benachrichtigungen: $e');
    }
  }

  static Future<void> markAsNotified(int id) async {
    try {
      final response = await ApiClient.dio.patch('$_path/$id/notified');
      if (response.statusCode != 200) {
        throw Exception('Fehler beim Markieren als benachrichtigt');
      }
    } catch (e) {
      throw Exception('Fehler beim Markieren als benachrichtigt: $e');
    }
  }
}

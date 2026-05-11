import 'package:productivity/dataclasses/journal_entry.dart';
import 'package:productivity/dataservice/api_client.dart';

class JournalService {
  JournalService._();
  static const String _path = '/journal';

  static Future<List<JournalEntry>> loadAll({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (dateFrom != null) {
        queryParams['start_date'] = dateFrom.toIso8601String().split('T')[0];
      }
      if (dateTo != null) {
        queryParams['end_date'] = dateTo.toIso8601String().split('T')[0];
      }

      final response = await ApiClient.dio.get(_path, queryParameters: queryParams);

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data is List ? response.data : [];
        return items.map((item) => JournalEntry.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Fehler beim Laden der Journaleinträge: $e');
    }
  }

  static Future<JournalEntry> getById(String id) async {
    try {
      final response = await ApiClient.dio.get('$_path/$id');
      return JournalEntry.fromJson(response.data);
    } catch (e) {
      throw Exception('Fehler beim Laden des Journaleintrags: $e');
    }
  }

  static Future<JournalEntry?> getByDate(DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final entries = await loadAll(
        dateFrom: date,
        dateTo: date,
      );

      if (entries.isNotEmpty) {
        return entries.firstWhere(
          (e) => e.date.toIso8601String().split('T')[0] == dateStr,
          orElse: () => entries.first,
        );
      }
      return null;
    } catch (e) {
      throw Exception('Fehler beim Laden des Eintrags: $e');
    }
  }

  static Future<JournalEntry> create(JournalEntry entry) async {
    try {
      final response = await ApiClient.dio.post(
        _path,
        data: {
          'content': entry.content,
          'date': null,
        },
      );
      return JournalEntry.fromJson(response.data);
    } catch (e) {
      throw Exception('Fehler beim Erstellen des Journaleintrags: $e');
    }
  }

  static Future<JournalEntry> update(JournalEntry entry) async {
    try {
      final response = await ApiClient.dio.put(
        '$_path/${entry.id}',
        data: {
          'content': entry.content,
        },
      );
      return JournalEntry.fromJson(response.data);
    } catch (e) {
      throw Exception('Fehler beim Aktualisieren des Journaleintrags: $e');
    }
  }

  static Future<void> delete(String id) async {
    try {
      await ApiClient.dio.delete('$_path/$id');
    } catch (e) {
      throw Exception('Fehler beim Löschen des Journaleintrags: $e');
    }
  }

  static Future<Map<String, dynamic>> getAnalytics({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (dateFrom != null) {
        queryParams['start_date'] = dateFrom.toIso8601String().split('T')[0];
      }
      if (dateTo != null) {
        queryParams['end_date'] = dateTo.toIso8601String().split('T')[0];
      }

      final response = await ApiClient.dio.get(
        '$_path/statistics/sentiment',
        queryParameters: queryParams,
      );

      return response.data ?? {};
    } catch (e) {
      throw Exception('Fehler beim Laden der Statistiken: $e');
    }
  }
}

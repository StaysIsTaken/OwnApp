import 'package:productivity/dataclasses/journal_analysis.dart';
import 'package:productivity/dataservice/api_client.dart';

class JournalAnalysisService {
  JournalAnalysisService._();
  static const String _path = '/journal-analyses';

  static Future<JournalAnalysis> getAnalysis(String journalEntryId) async {
    try {
      final response = await ApiClient.dio.get('$_path/$journalEntryId');
      return JournalAnalysis.fromJson(response.data);
    } catch (e) {
      throw Exception('Fehler beim Laden der Analyse: $e');
    }
  }

  static Future<List<JournalAnalysis>> getAnalysesByDateRange({
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
        _path,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data is List ? response.data : [];
        return items
            .map((item) => JournalAnalysis.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Fehler beim Laden der Analysen: $e');
    }
  }
}

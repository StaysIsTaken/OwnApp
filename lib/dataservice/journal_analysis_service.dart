import 'package:productivity/dataclasses/journal_analysis.dart';
import 'package:productivity/dataservice/api_client.dart';

class JournalAnalysisService {
  JournalAnalysisService._();

  /// Speichert eine Analyse für einen Journal-Eintrag
  /// POST /api/journal/{entry_id}/analysis
  static Future<JournalAnalysis> saveAnalysis({
    required String journalEntryId,
    required double sentimentScore,
    required String sentimentLabel,
    List<String>? detectedTopics,
    String? summary,
    String? rawAnalysis,
  }) async {
    try {
      final response = await ApiClient.dio.post(
        '/journal/$journalEntryId/analysis',
        data: {
          'sentimentScore': sentimentScore,
          'sentimentLabel': sentimentLabel,
          if (detectedTopics != null) 'detectedTopics': detectedTopics,
          if (summary != null) 'summary': summary,
          if (rawAnalysis != null) 'rawAnalysis': rawAnalysis,
        },
      );
      return JournalAnalysis.fromJson(response.data);
    } catch (e) {
      throw Exception('Fehler beim Speichern der Analyse: $e');
    }
  }

  /// Ruft die Analyse für einen Journal-Eintrag ab
  /// GET /api/journal/{entry_id}/analysis
  static Future<JournalAnalysis?> getAnalysis(String journalEntryId) async {
    try {
      final response = await ApiClient.dio.get(
        '/journal/$journalEntryId/analysis',
      );

      if (response.statusCode == 200 && response.data != null) {
        return JournalAnalysis.fromJson(response.data);
      }
      return null;
    } catch (e) {
      // Stille Fehler - Analyse existiert möglicherweise nicht
      return null;
    }
  }

  /// Ruft Sentiment-Statistiken ab
  /// GET /api/journal/statistics/sentiment
  static Future<Map<String, dynamic>> getSentimentStatistics({
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
        '/journal/statistics/sentiment',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      return response.data ?? {};
    } catch (e) {
      throw Exception('Fehler beim Laden der Statistiken: $e');
    }
  }
}

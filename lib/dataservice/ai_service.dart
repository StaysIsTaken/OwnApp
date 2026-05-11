import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:productivity/dataclasses/ai_model.dart';
import 'package:productivity/dataservice/api_client.dart';

class AIService {
  AIService._();
  static const String _path = '/ollama';

  static Future<List<AIModel>> getAvailableModels() async {
    try {
      final response = await ApiClient.dio.get('$_path/tags');

      if (response.statusCode == 200) {
        final List<dynamic> models = response.data['models'] ?? [];
        return models.map((model) => AIModel.fromJson(model as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Fehler beim Laden der Modelle: $e');
    }
  }

  /// Generate text with streaming
  /// Calls onChunk(text) for each chunk of generated text
  /// Returns when generation is complete (done: true)
  static Future<void> generateText({
    required String model,
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 500,
    required Function(String) onChunk,
  }) async {
    try {
      final response = await ApiClient.dio.post(
        '$_path/generate',
        data: {
          'model': model,
          'prompt': prompt,
          'stream': true,
          'temperature': temperature,
          'num_predict': maxTokens,
        },
        options: Options(
          responseType: ResponseType.stream,
          contentType: 'application/json',
        ),
      );

      if (response.statusCode == 200) {
        final stream = response.data.stream;

        await stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          if (line.isNotEmpty) {
            try {
              final json = jsonDecode(line) as Map<String, dynamic>;
              final text = json['response'] ?? '';
              if (text.isNotEmpty) {
                onChunk(text);
              }
            } catch (e) {
              // Ignore JSON parse errors
            }
          }
        }).asFuture();
      }
    } catch (e) {
      throw Exception('Fehler beim Generieren von Text: $e');
    }
  }

  /// Enhance/improve existing text with streaming
  static Future<void> enhanceText({
    required String model,
    required String text,
    required String instruction,
    double temperature = 0.7,
    int maxTokens = 500,
    required Function(String) onChunk,
  }) async {
    try {
      final prompt =
          'Improve the following text according to this instruction: "$instruction"\n\nOriginal text:\n$text\n\nImproved text:';

      await generateText(
        model: model,
        prompt: prompt,
        temperature: temperature,
        maxTokens: maxTokens,
        onChunk: onChunk,
      );
    } catch (e) {
      throw Exception('Fehler beim Verbessern von Text: $e');
    }
  }

  /// Chat with the model using message history
  static Future<void> chatStream({
    required String model,
    required List<Map<String, String>> messages,
    double temperature = 0.7,
    int maxTokens = 500,
    required Function(String) onChunk,
  }) async {
    try {
      final response = await ApiClient.dio.post(
        '$_path/chat',
        data: {
          'model': model,
          'messages': messages,
          'stream': true,
          'temperature': temperature,
          'num_predict': maxTokens,
        },
        options: Options(
          responseType: ResponseType.stream,
          contentType: 'application/json',
        ),
      );

      if (response.statusCode == 200) {
        final stream = response.data.stream;

        await stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          if (line.isNotEmpty) {
            try {
              final json = jsonDecode(line) as Map<String, dynamic>;
              final text = json['response'] ?? '';
              if (text.isNotEmpty) {
                onChunk(text);
              }
            } catch (e) {
              // Ignore JSON parse errors
            }
          }
        }).asFuture();
      }
    } catch (e) {
      throw Exception('Fehler beim Chat: $e');
    }
  }

  /// Generate analysis prompt for journal entries
  static String getJournalAnalysisPrompt(String content) {
    return '''Analyze this journal entry and provide:
1. Sentiment score from -1 (very negative) to 1 (very positive)
2. Sentiment label: "positive", "neutral", or "negative"
3. Detected topics/themes (comma-separated)
4. Brief summary (1-2 sentences)

Journal entry:
$content

Please respond in this exact JSON format:
{
  "sentiment_score": 0.5,
  "sentiment_label": "positive",
  "detected_topics": "Topic1, Topic2, Topic3",
  "summary": "Brief summary here"
}''';
  }

  /// Generate text enhancement prompt
  static String getEnhancementPrompt(String text, String instruction) {
    return 'Improve the following text according to this instruction: "$instruction"\n\nOriginal text:\n$text\n\nImproved text:';
  }
}

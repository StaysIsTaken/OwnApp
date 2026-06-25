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

  /// Liefert ein tatsächlich auf dem Server verfügbares Modell:
  /// das bevorzugte, falls vorhanden – sonst das erste verfügbare.
  /// Wirft, wenn gar kein Modell installiert ist.
  static Future<String> resolveModel(String preferred) async {
    final models = await getAvailableModels();
    if (models.isEmpty) {
      throw Exception(
          'Auf dem Server ist kein KI-Modell installiert (Ollama).');
    }
    if (preferred.isNotEmpty && models.any((m) => m.name == preferred)) {
      return preferred;
    }
    return models.first.name;
  }

  /// Generiert den kompletten Text. Intern wird GESTREAMT (stream:true) und
  /// zusammengesetzt — so fließen laufend Daten, damit Proxies/Cloudflare nicht
  /// mit Timeout (524) abbrechen. maxTokens begrenzt die Generierungsdauer.
  static Future<String> generateTextComplete({
    required String model,
    required String prompt,
    int? maxTokens,
    double? temperature,
  }) async {
    final buffer = StringBuffer();
    await generateText(
      model: model,
      prompt: prompt,
      maxTokens: maxTokens,
      temperature: temperature,
      onChunk: (chunk) => buffer.write(chunk),
    );
    return buffer.toString();
  }

  /// Generate text with streaming (optional - für Live-Text Ansicht)
  /// Calls onChunk(text) for each chunk of generated text
  static Future<void> generateText({
    required String model,
    required String prompt,
    required Function(String) onChunk,
    int? maxTokens,
    double? temperature,
  }) async {
    try {
      final options = <String, dynamic>{};
      if (maxTokens != null) options['num_predict'] = maxTokens;
      if (temperature != null) options['temperature'] = temperature;

      final response = await ApiClient.dio.post(
        '$_path/generate',
        data: {
          'model': model,
          'prompt': prompt,
          'stream': true,
          if (options.isNotEmpty) 'options': options,
        },
        options: Options(
          responseType: ResponseType.stream,
          contentType: 'application/json',
        ),
      );

      if (response.statusCode == 200) {
        final Stream<String> lines = const LineSplitter()
            .bind(utf8.decoder.bind(response.data.stream));

        await lines.forEach((line) {
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
        });
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
    required Function(String) onChunk,
  }) async {
    try {
      final prompt =
          'Improve the following text according to this instruction: "$instruction"\n\nOriginal text:\n$text\n\nImproved text:';

      await generateText(
        model: model,
        prompt: prompt,
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
    required Function(String) onChunk,
  }) async {
    try {
      final response = await ApiClient.dio.post(
        '$_path/chat',
        data: {
          'model': model,
          'messages': messages,
          'stream': true,
        },
        options: Options(
          responseType: ResponseType.stream,
          contentType: 'application/json',
        ),
      );

      if (response.statusCode == 200) {
        final Stream<String> lines = const LineSplitter()
            .bind(utf8.decoder.bind(response.data.stream));

        await lines.forEach((line) {
          if (line.isNotEmpty) {
            try {
              final json = jsonDecode(line) as Map<String, dynamic>;
              final message = json['message'] as Map<String, dynamic>?;
              final text = message?['content'] ?? '';
              if (text.isNotEmpty) {
                onChunk(text);
              }
            } catch (e) {
              // Ignore JSON parse errors
            }
          }
        });
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

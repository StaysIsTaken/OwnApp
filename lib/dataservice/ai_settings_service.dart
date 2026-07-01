import 'package:productivity/dataservice/api_client.dart';

/// Pro-User KI-Provider-Einstellungen (serverseitig gespeichert).
class AiSettings {
  final String provider; // ollama | openrouter | gemini
  final String? baseUrl;
  final String? model;
  final bool hasKey; // ob ein API-Key hinterlegt ist (der Key selbst kommt nie zurück)
  final int? maxTokens;
  final double? temperature;

  AiSettings({
    required this.provider,
    this.baseUrl,
    this.model,
    this.hasKey = false,
    this.maxTokens,
    this.temperature,
  });

  factory AiSettings.fromJson(Map<String, dynamic> j) => AiSettings(
        provider: (j['provider'] ?? 'ollama').toString(),
        baseUrl: j['base_url'] as String?,
        model: j['model'] as String?,
        hasKey: j['has_key'] == true,
        maxTokens: j['max_tokens'] as int?,
        temperature: (j['temperature'] as num?)?.toDouble(),
      );
}

class AiSettingsService {
  AiSettingsService._();
  static const String _path = '/assistant/settings';

  static Future<AiSettings> get() async {
    final r = await ApiClient.dio.get(_path);
    return AiSettings.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// Speichert nur die übergebenen Felder. apiKey: nicht-null = setzen
  /// (leerer String löscht ihn serverseitig), null = unverändert lassen.
  static Future<AiSettings> save({
    String? provider,
    String? apiKey,
    String? baseUrl,
    String? model,
    int? maxTokens,
    double? temperature,
  }) async {
    final body = <String, dynamic>{};
    if (provider != null) body['provider'] = provider;
    if (apiKey != null) body['api_key'] = apiKey;
    if (baseUrl != null) body['base_url'] = baseUrl;
    if (model != null) body['model'] = model;
    if (maxTokens != null) body['max_tokens'] = maxTokens;
    if (temperature != null) body['temperature'] = temperature;
    final r = await ApiClient.dio.put(_path, data: body);
    return AiSettings.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// Fragt die verfügbaren Modelle beim Anbieter ab (Key muss vorher
  /// gespeichert sein). Wirft mit dem Server-Fehlertext bei Problemen.
  static Future<List<String>> listModels() async {
    final r = await ApiClient.dio.get('$_path/models');
    final data = Map<String, dynamic>.from(r.data as Map);
    return ((data['models'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
  }
}

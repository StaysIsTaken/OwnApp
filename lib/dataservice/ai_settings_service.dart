import 'package:productivity/dataservice/api_client.dart';

/// Ein KI-Anbieter-Profil eines Nutzers (mehrere möglich, eines aktiv).
class AiProvider {
  final String id;
  final String name;
  final String provider; // ollama | openrouter | gemini | mistral | custom
  final String? baseUrl;
  final String? model;
  final bool hasKey;
  final bool isActive;

  AiProvider({
    required this.id,
    required this.name,
    required this.provider,
    this.baseUrl,
    this.model,
    this.hasKey = false,
    this.isActive = false,
  });

  factory AiProvider.fromJson(Map<String, dynamic> j) => AiProvider(
        id: j['id'].toString(),
        name: (j['name'] ?? '').toString(),
        provider: (j['provider'] ?? 'custom').toString(),
        baseUrl: j['base_url'] as String?,
        model: j['model'] as String?,
        hasKey: j['has_key'] == true,
        isActive: j['is_active'] == true,
      );
}

class AiSettingsService {
  AiSettingsService._();
  static const String _base = '/assistant/providers';

  static Future<List<AiProvider>> list() async {
    final r = await ApiClient.dio.get(_base);
    return (r.data as List)
        .map((e) => AiProvider.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<AiProvider> create({
    required String name,
    required String provider,
    String? baseUrl,
    String? apiKey,
    String? model,
  }) async {
    final r = await ApiClient.dio.post(_base, data: {
      'name': name,
      'provider': provider,
      if (baseUrl != null) 'base_url': baseUrl,
      if (apiKey != null) 'api_key': apiKey,
      if (model != null) 'model': model,
    });
    return AiProvider.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  static Future<AiProvider> update(
    String id, {
    String? name,
    String? provider,
    String? baseUrl,
    String? apiKey,
    String? model,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (provider != null) body['provider'] = provider;
    if (baseUrl != null) body['base_url'] = baseUrl;
    if (apiKey != null) body['api_key'] = apiKey;
    if (model != null) body['model'] = model;
    final r = await ApiClient.dio.put('$_base/$id', data: body);
    return AiProvider.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  static Future<void> delete(String id) async {
    await ApiClient.dio.delete('$_base/$id');
  }

  static Future<AiProvider> activate(String id) async {
    final r = await ApiClient.dio.post('$_base/$id/activate');
    return AiProvider.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// Modelle des Anbieters mit der gegebenen id (Key muss gespeichert sein).
  static Future<List<String>> listModels(String id) async {
    final r = await ApiClient.dio.get('$_base/$id/models');
    final data = Map<String, dynamic>.from(r.data as Map);
    return ((data['models'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
  }
}

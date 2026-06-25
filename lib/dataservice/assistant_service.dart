import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:productivity/dataservice/api_client.dart';

class AssistantPendingAction {
  final String kind;
  final String label;
  final Map<String, dynamic> params;
  AssistantPendingAction(
      {required this.kind, required this.label, required this.params});

  factory AssistantPendingAction.fromJson(Map<String, dynamic> json) {
    return AssistantPendingAction(
      kind: json['kind'] ?? '',
      label: json['label'] ?? '',
      params: Map<String, dynamic>.from(json['params'] ?? {}),
    );
  }
}

class AssistantReply {
  final String reply;
  final List<AssistantPendingAction> pendingActions;
  AssistantReply({required this.reply, required this.pendingActions});
}

class AssistantService {
  AssistantService._();
  static const String _path = '/assistant';

  /// messages: Liste von {role: 'user'|'assistant', content: ...}
  ///
  /// Der Endpunkt streamt NDJSON: laufend {"type":"heartbeat"} (damit
  /// Cloudflare nicht mit 524 abbricht) und am Ende {"type":"result", ...}
  /// bzw. {"type":"error"}. Wir lesen den Stream Zeile für Zeile und werten
  /// nur die finale Zeile aus.
  static Future<AssistantReply> chat({
    required List<Map<String, String>> messages,
    String? model,
  }) async {
    try {
      final response = await ApiClient.dio.post(
        '$_path/chat',
        data: {
          'messages': messages,
          'model': model,
        },
        options: Options(
          responseType: ResponseType.stream,
          contentType: 'application/json',
        ),
      );

      Map<String, dynamic>? result;
      String? error;

      await response.data.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.trim().isEmpty) return;
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          switch (json['type']) {
            case 'result':
              result = json;
              break;
            case 'error':
              error = (json['detail'] ?? 'Unbekannter Fehler').toString();
              break;
            // 'heartbeat' wird ignoriert
          }
        } catch (_) {
          // unvollständige/ungültige Zeile ignorieren
        }
      }).asFuture();

      if (error != null) throw Exception(error);
      if (result == null) {
        throw Exception('Keine Antwort vom Assistenten erhalten.');
      }
      return AssistantReply(
        reply: (result!['reply'] ?? '').toString(),
        pendingActions: (result!['pending_actions'] as List?)
                ?.map((e) =>
                    AssistantPendingAction.fromJson(e as Map<String, dynamic>))
                .toList() ??
            <AssistantPendingAction>[],
      );
    } catch (e) {
      throw Exception('Fehler beim Assistenten: $e');
    }
  }

  /// Führt eine vom Nutzer bestätigte Aktion serverseitig aus.
  /// Gibt 'affects' zurück (z.B. 'planner'), damit die App neu laden kann.
  static Future<String?> execute(
      String kind, Map<String, dynamic> params) async {
    try {
      final response = await ApiClient.dio.post('$_path/execute', data: {
        'kind': kind,
        'params': params,
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      return data['affects'] as String?;
    } catch (e) {
      throw Exception('Fehler beim Ausführen: $e');
    }
  }
}

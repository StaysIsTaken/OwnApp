import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:productivity/dataservice/api_client.dart';
import 'package:productivity/dataservice/assistant_service.dart';

/// Lädt ein Kassenbon-Foto hoch und erhält Artikel-Vorschläge als
/// [AssistantPendingAction]s (kind add_pantry_item / add_shopping_item).
class ReceiptService {
  ReceiptService._();
  static const String _path = '/receipt';

  /// target: 'pantry' (Vorräte) oder 'shopping' (Einkaufsliste).
  static Future<List<AssistantPendingAction>> scan(
    Uint8List bytes, {
    String target = 'pantry',
    String filename = 'receipt.jpg',
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await ApiClient.dio.post(
      _path,
      data: form,
      queryParameters: {'target': target},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data['pending_actions'] as List?)
            ?.map((e) =>
                AssistantPendingAction.fromJson(e as Map<String, dynamic>))
            .toList() ??
        <AssistantPendingAction>[];
  }
}

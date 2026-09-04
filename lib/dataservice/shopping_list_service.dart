import 'package:productivity/dataclasses/pantry_extras.dart';
import 'package:productivity/dataservice/api_client.dart';

class ShoppingListService {
  ShoppingListService._();

  static const String _path = '/shopping-list';

  static Future<List<ShoppingListItem>> loadAll() async {
    final response = await ApiClient.dio.get(_path);
    // API returns {"total": X, "items": [...]}
    final list = response.data['items'] as List<dynamic>;
    return list.map((e) => ShoppingListItem.fromJson(e)).toList();
  }

  static Future<ShoppingListItem> upsert(ShoppingListItem item) async {
    if (item.id.isEmpty) {
      final response = await ApiClient.dio.post(_path, data: item.toJson());
      return ShoppingListItem.fromJson(response.data);
    } else {
      final response = await ApiClient.dio.put('$_path/${item.id}', data: item.toJson());
      return ShoppingListItem.fromJson(response.data);
    }
  }

  static Future<void> delete(String id) async {
    await ApiClient.dio.delete('$_path/$id');
  }

  /// Bucht alle abgehakten Posten in den Vorrat und räumt sie von der Liste.
  /// Gibt die Anzahl der übernommenen Posten zurück.
  static Future<int> transferToPantry() async {
    final response = await ApiClient.dio.post('$_path/transfer-to-pantry');
    return (response.data['count'] as num?)?.toInt() ?? 0;
  }
}

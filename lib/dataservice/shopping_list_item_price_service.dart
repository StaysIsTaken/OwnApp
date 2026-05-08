import 'package:productivity/dataclasses/shopping_list_item_price.dart';
import 'package:productivity/dataservice/api_client.dart';

class ShoppingListItemPriceService {
  ShoppingListItemPriceService._();

  static const String _path = '/shopping-list-prices';

  static Future<List<ShoppingListItemPrice>> loadByItemId(String itemId) async {
    final response = await ApiClient.dio.get(
      _path,
      queryParameters: {'itemId': itemId},
    );

    final listRaw = response.data is Map ? response.data['items'] ?? [] : response.data;
    return (listRaw as List)
        .map((item) => ShoppingListItemPrice.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<ShoppingListItemPrice> create(ShoppingListItemPrice price) async {
    final payload = {
      'shoppingListItemId': price.shoppingListItemId,
      'shopId': price.shopId,
      'price': price.price,
      'date': price.date.toIso8601String().split('T')[0],
    };

    final response = await ApiClient.dio.post(_path, data: payload);
    return ShoppingListItemPrice.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<ShoppingListItemPrice> update(ShoppingListItemPrice price) async {
    final payload = {
      'shopId': price.shopId,
      'price': price.price,
      'date': price.date.toIso8601String().split('T')[0],
    };

    final response = await ApiClient.dio.put('$_path/${price.id}', data: payload);
    return ShoppingListItemPrice.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> delete(String priceId) async {
    await ApiClient.dio.delete('$_path/$priceId');
  }
}

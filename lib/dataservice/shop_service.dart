import 'package:productivity/dataclasses/shop.dart';
import 'package:productivity/dataservice/api_client.dart';

class ShopService {
  ShopService._();

  static const String _path = '/shops';

  static Future<List<Shop>> loadAll() async {
    final response = await ApiClient.dio.get(_path);
    // API returns {"total": X, "items": [...]} or just a list
    final listRaw = response.data is Map ? response.data['items'] ?? [] : response.data;
    return (listRaw as List)
        .map((item) => Shop.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<Shop> create(Shop shop) async {
    final payload = {
      'name': shop.name,
    };

    final response = await ApiClient.dio.post(_path, data: payload);
    return Shop.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> delete(String shopId) async {
    await ApiClient.dio.delete('$_path/$shopId');
  }
}

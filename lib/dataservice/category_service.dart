import 'package:productivity/dataclasses/category.dart';
import 'package:productivity/dataservice/api_client.dart';

// ─────────────────────────────────────────────
//  CategoryService – API-backed
// ─────────────────────────────────────────────
class CategoryService {
  CategoryService._();

  static const String _path = '/categories';

  static Future<List<Category>> loadAll() async {
    final response = await ApiClient.dio.get(_path);
    return (response.data['items'] as List<dynamic>)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Category> getById(String id) async {
    final response = await ApiClient.dio.get('$_path/$id');
    return Category.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Category> create(Category category) async {
    final response = await ApiClient.dio.post(
      _path,
      data: category.toJson(),
    );
    return Category.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Category> update(Category category) async {
    final response = await ApiClient.dio.put(
      '$_path/${category.id}',
      data: category.toJson(),
    );
    return Category.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> delete(String id) async {
    await ApiClient.dio.delete('$_path/$id');
  }

  /// Inserts or replaces – convenience wrapper kept for API compatibility.
  static Future<void> upsert(Category category) async {
    try {
      await update(category);
    } catch (_) {
      await create(category);
    }
  }
}

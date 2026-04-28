import 'package:productivity/dataclasses/ingredient.dart';
import 'package:productivity/dataservice/api_client.dart';

// ─────────────────────────────────────────────
//  IngredientService – API-backed
// ─────────────────────────────────────────────
class IngredientService {
  IngredientService._();

  static const String _path = '/ingredients';

  static Future<List<Ingredient>> loadAll() async {
    final response = await ApiClient.dio.get(_path);
    return (response.data['items'] as List<dynamic>)
        .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Ingredient> getById(String id) async {
    final response = await ApiClient.dio.get('$_path/$id');
    return Ingredient.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Ingredient> create(Ingredient ingredient) async {
    final response = await ApiClient.dio.post(
      _path,
      data: ingredient.toJson(),
    );
    return Ingredient.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Ingredient> update(Ingredient ingredient) async {
    final response = await ApiClient.dio.put(
      '$_path/${ingredient.id}',
      data: ingredient.toJson(),
    );
    return Ingredient.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> delete(String id) async {
    await ApiClient.dio.delete('$_path/$id');
  }

  /// Inserts or replaces – convenience wrapper kept for API compatibility.
  static Future<void> upsert(Ingredient ingredient) async {
    try {
      await update(ingredient);
    } catch (_) {
      await create(ingredient);
    }
  }
}

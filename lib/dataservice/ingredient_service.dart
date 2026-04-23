import 'package:shared_preferences/shared_preferences.dart';
import 'package:productivity/models/ingredient.dart';

// ─────────────────────────────────────────────
//  IngredientService
// ─────────────────────────────────────────────
class IngredientService {
  IngredientService._();

  static const String _key = 'ingredients';

  static Future<List<Ingredient>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? [])
        .map(Ingredient.fromJsonString)
        .toList();
  }

  /// Inserts a new ingredient or replaces an existing one with the same id.
  static Future<void> upsert(Ingredient ingredient) async {
    final items = await loadAll();
    final idx = items.indexWhere((i) => i.id == ingredient.id);
    if (idx >= 0) {
      items[idx] = ingredient;
    } else {
      items.add(ingredient);
    }
    await _persist(items);
  }

  static Future<void> delete(String id) async {
    final items = await loadAll();
    items.removeWhere((i) => i.id == id);
    await _persist(items);
  }

  static Future<void> _persist(List<Ingredient> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, items.map((i) => i.toJsonString()).toList());
  }
}

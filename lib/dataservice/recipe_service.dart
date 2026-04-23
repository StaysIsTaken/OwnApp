import 'package:shared_preferences/shared_preferences.dart';
import 'package:productivity/models/recipe.dart';

// ─────────────────────────────────────────────
//  RecipeService
// ─────────────────────────────────────────────
class RecipeService {
  RecipeService._();

  static const String _key = 'recipes';

  static Future<List<Recipe>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? [])
        .map(Recipe.fromJsonString)
        .toList();
  }

  /// Inserts a new recipe or replaces an existing one with the same id.
  static Future<void> upsert(Recipe recipe) async {
    final items = await loadAll();
    final idx = items.indexWhere((i) => i.id == recipe.id);
    if (idx >= 0) {
      items[idx] = recipe;
    } else {
      items.add(recipe);
    }
    await _persist(items);
  }

  static Future<void> delete(String id) async {
    final items = await loadAll();
    items.removeWhere((i) => i.id == id);
    await _persist(items);
  }

  static Future<void> _persist(List<Recipe> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, items.map((i) => i.toJsonString()).toList());
  }
}

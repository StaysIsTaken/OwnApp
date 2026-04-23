import 'package:shared_preferences/shared_preferences.dart';
import 'package:productivity/models/category.dart';

// ─────────────────────────────────────────────
//  CategoryService
// ─────────────────────────────────────────────
class CategoryService {
  CategoryService._();

  static const String _key = 'recipe_categories';

  static Future<List<Category>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? [])
        .map(Category.fromJsonString)
        .toList();
  }

  /// Inserts a new category or replaces an existing one with the same id.
  static Future<void> upsert(Category category) async {
    final items = await loadAll();
    final idx = items.indexWhere((i) => i.id == category.id);
    if (idx >= 0) {
      items[idx] = category;
    } else {
      items.add(category);
    }
    await _persist(items);
  }

  static Future<void> delete(String id) async {
    final items = await loadAll();
    items.removeWhere((i) => i.id == id);
    await _persist(items);
  }

  static Future<void> _persist(List<Category> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, items.map((i) => i.toJsonString()).toList());
  }
}

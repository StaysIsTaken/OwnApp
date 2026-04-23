import 'package:shared_preferences/shared_preferences.dart';
import 'package:productivity/models/unit.dart';

// ─────────────────────────────────────────────
//  UnitService
// ─────────────────────────────────────────────
class UnitService {
  UnitService._();

  static const String _key = 'units';

  static Future<List<Unit>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).map(Unit.fromJsonString).toList();
  }

  /// Inserts a new unit or replaces an existing one with the same id.
  static Future<void> upsert(Unit unit) async {
    final items = await loadAll();
    final idx = items.indexWhere((i) => i.id == unit.id);
    if (idx >= 0) {
      items[idx] = unit;
    } else {
      items.add(unit);
    }
    await _persist(items);
  }

  static Future<void> delete(String id) async {
    final items = await loadAll();
    items.removeWhere((i) => i.id == id);
    await _persist(items);
  }

  static Future<void> _persist(List<Unit> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, items.map((i) => i.toJsonString()).toList());
  }
}

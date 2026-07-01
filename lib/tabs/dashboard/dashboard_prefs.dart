import 'package:shared_preferences/shared_preferences.dart';

/// Pro-Nutzer (lokal) gespeicherte Dashboard-Anpassung: Reihenfolge und
/// Sichtbarkeit der Widget-Kacheln.
class DashboardPrefs {
  static const _orderKey = 'dash_order_v1';
  static const _hiddenKey = 'dash_hidden_v1';

  /// Alle anpassbaren Kacheln in Standardreihenfolge.
  static const List<String> allKeys = [
    'tasks', 'time', 'shopping', 'pantry', 'mealplan', 'journal', 'notes',
  ];

  static const Map<String, String> labels = {
    'tasks': 'Aufgaben',
    'time': 'Zeit',
    'shopping': 'Einkauf',
    'pantry': 'Vorräte',
    'mealplan': 'Essensplan',
    'journal': 'Journal',
    'notes': 'Notizen',
  };

  static Future<List<String>> loadOrder() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getStringList(_orderKey);
    final order = <String>[];
    if (saved != null) {
      for (final k in saved) {
        if (allKeys.contains(k) && !order.contains(k)) order.add(k);
      }
    }
    // Neue/fehlende Kacheln hinten anhängen (sichtbar per Default).
    for (final k in allKeys) {
      if (!order.contains(k)) order.add(k);
    }
    return order;
  }

  static Future<Set<String>> loadHidden() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_hiddenKey) ?? const <String>[])
        .where(allKeys.contains)
        .toSet();
  }

  static Future<void> save(List<String> order, Set<String> hidden) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_orderKey, order);
    await p.setStringList(_hiddenKey, hidden.toList());
  }
}

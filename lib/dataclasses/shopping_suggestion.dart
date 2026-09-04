// ─────────────────────────────────────────────
//  Vorschlag für die Einkaufsliste, abgeleitet
//  aus dem Essensplan (Bedarf minus Vorrat).
// ─────────────────────────────────────────────
class ShoppingSuggestion {
  final String ingredientId;
  final String ingredientName;
  final String? unitId;
  final String? unitSymbol;
  final double needed;
  final double inPantry;
  final double toBuy;

  /// False, wenn der Vorrat in einer anderen Einheit geführt wird als die
  /// Zutat – dann konnte er nicht gegengerechnet werden.
  final bool pantryComparable;

  /// Rezepte, aus denen dieser Bedarf stammt.
  final List<String> recipes;

  const ShoppingSuggestion({
    required this.ingredientId,
    required this.ingredientName,
    this.unitId,
    this.unitSymbol,
    required this.needed,
    required this.inPantry,
    required this.toBuy,
    required this.pantryComparable,
    required this.recipes,
  });

  factory ShoppingSuggestion.fromJson(Map<String, dynamic> j) => ShoppingSuggestion(
        ingredientId: j['ingredientId']?.toString() ?? '',
        ingredientName: j['ingredientName']?.toString() ?? '',
        unitId: j['unitId']?.toString(),
        unitSymbol: j['unitSymbol']?.toString(),
        needed: (j['needed'] as num?)?.toDouble() ?? 0,
        inPantry: (j['inPantry'] as num?)?.toDouble() ?? 0,
        toBuy: (j['toBuy'] as num?)?.toDouble() ?? 0,
        pantryComparable: j['pantryComparable'] != false,
        recipes: (j['recipes'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

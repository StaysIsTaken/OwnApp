import 'dart:convert';

// ─────────────────────────────────────────────
//  RecipeIngredient – Bridge / Junction class
//  Links an Ingredient to a Recipe and stores
//  the amount + the unit used for that recipe.
// ─────────────────────────────────────────────
class RecipeIngredient {
  final String? id;
  final String ingredientId;
  final String? unitId; // no longer needed for backend, but keeping for UI compatibility if needed
  final double amount;

  const RecipeIngredient({
    this.id,
    required this.ingredientId,
    this.unitId,
    required this.amount,
  });

  RecipeIngredient copyWith({
    String? id,
    String? ingredientId,
    String? unitId,
    double? amount,
  }) =>
      RecipeIngredient(
        id: id ?? this.id,
        ingredientId: ingredientId ?? this.ingredientId,
        unitId: unitId ?? this.unitId,
        amount: amount ?? this.amount,
      );

  Map<String, dynamic> toJson() => {
        'ingredient_id': ingredientId,
        'amount': amount,
      };

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) => RecipeIngredient(
        id: j['id']?.toString(),
        ingredientId: j['ingredient_id']?.toString() ?? '',
        unitId: j['unit_id']?.toString(), // Ensure unit_id is parsed if present
        amount: (j['amount'] as num?)?.toDouble() ?? 0.0,
      );

  String toJsonString() => jsonEncode(toJson());

  factory RecipeIngredient.fromJsonString(String s) =>
      RecipeIngredient.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

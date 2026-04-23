import 'dart:convert';

// ─────────────────────────────────────────────
//  RecipeIngredient – Bridge / Junction class
//  Links an Ingredient to a Recipe and stores
//  the amount + the unit used for that recipe.
// ─────────────────────────────────────────────
class RecipeIngredient {
  final String ingredientId;
  final String unitId;
  final double amount;

  const RecipeIngredient({
    required this.ingredientId,
    required this.unitId,
    required this.amount,
  });

  RecipeIngredient copyWith({
    String? ingredientId,
    String? unitId,
    double? amount,
  }) =>
      RecipeIngredient(
        ingredientId: ingredientId ?? this.ingredientId,
        unitId: unitId ?? this.unitId,
        amount: amount ?? this.amount,
      );

  Map<String, dynamic> toJson() => {
        'ingredientId': ingredientId,
        'unitId': unitId,
        'amount': amount,
      };

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) => RecipeIngredient(
        ingredientId: j['ingredientId'] as String,
        unitId: j['unitId'] as String,
        amount: (j['amount'] as num).toDouble(),
      );

  String toJsonString() => jsonEncode(toJson());

  factory RecipeIngredient.fromJsonString(String s) =>
      RecipeIngredient.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

import 'dart:convert';
import 'package:productivity/models/recipe_ingredient.dart';

// ─────────────────────────────────────────────
//  Recipe – stores ingredients inline as a list
//  of RecipeIngredient (bridge objects).
// ─────────────────────────────────────────────
class Recipe {
  final String id;
  final String name;
  final String? categoryId;
  final String? description;
  final List<RecipeIngredient> ingredients;

  const Recipe({
    required this.id,
    required this.name,
    this.categoryId,
    this.description,
    this.ingredients = const [],
  });

  Recipe copyWith({
    String? id,
    String? name,
    String? categoryId,
    bool clearCategory = false,
    String? description,
    List<RecipeIngredient>? ingredients,
  }) =>
      Recipe(
        id: id ?? this.id,
        name: name ?? this.name,
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        description: description ?? this.description,
        ingredients: ingredients ?? this.ingredients,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'categoryId': categoryId,
        'description': description,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
      };

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: j['id'] as String,
        name: j['name'] as String,
        categoryId: j['categoryId'] as String?,
        description: j['description'] as String?,
        ingredients: (j['ingredients'] as List<dynamic>)
            .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String toJsonString() => jsonEncode(toJson());

  factory Recipe.fromJsonString(String s) =>
      Recipe.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

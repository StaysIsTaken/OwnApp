import 'dart:convert';
import 'package:productivity/dataclasses/recipe_ingredient.dart';

// ─────────────────────────────────────────────
//  Recipe – stores ingredients inline as a list
//  of RecipeIngredient (bridge objects).
// ─────────────────────────────────────────────
class Recipe {
  final String id;
  final String name;
  final List<String> categoryIds; // Changed from categoryId to categoryIds
  final String? description;
  final List<RecipeIngredient> ingredients;

  const Recipe({
    required this.id,
    required this.name,
    this.categoryIds = const [],
    this.description,
    this.ingredients = const [],
  });

  Recipe copyWith({
    String? id,
    String? name,
    List<String>? categoryIds,
    String? description,
    List<RecipeIngredient>? ingredients,
  }) =>
      Recipe(
        id: id ?? this.id,
        name: name ?? this.name,
        categoryIds: categoryIds ?? this.categoryIds,
        description: description ?? this.description,
        ingredients: ingredients ?? this.ingredients,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category_ids': categoryIds, // Changed key name for backend consistency
        'description': description,
      };

  factory Recipe.fromJson(Map<String, dynamic> j) {
    // Handle old single categoryId for backward compatibility if needed, 
    // but primarily use category_ids list.
    List<String> cats = [];
    if (j.containsKey('category_ids') && j['category_ids'] != null) {
      cats = (j['category_ids'] as List<dynamic>).map((e) => e.toString()).toList();
    } else if (j.containsKey('category_id') && j['category_id'] != null) {
      cats = [j['category_id'].toString()];
    }

    return Recipe(
      id: j['id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      categoryIds: cats,
      description: j['description']?.toString(),
      ingredients: j.containsKey('ingredients')
          ? (j['ingredients'] as List<dynamic>)
              .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Recipe.fromJsonString(String s) =>
      Recipe.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

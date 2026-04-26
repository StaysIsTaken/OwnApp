import 'package:productivity/dataclasses/recipe.dart';
import 'package:productivity/dataclasses/recipe_ingredient.dart';
import 'package:productivity/dataservice/api_client.dart';

// ─────────────────────────────────────────────
//  RecipeService – API-backed
// ─────────────────────────────────────────────
class RecipeService {
  RecipeService._();

  static const String _path = '/recipes';

  static Future<List<Recipe>> loadAll() async {
    final response = await ApiClient.dio.get(_path);
    final recipesRaw = response.data['items'] as List<dynamic>;

    final recipes = recipesRaw
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();

    final results = await Future.wait(recipes.map((r) => getIngredients(r.id)));

    return List.generate(recipes.length, (i) {
      final recipe = recipes[i];
      final ingsRaw = results[i];
      final ings = ingsRaw
          .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
          .toList();
      return recipe.copyWith(ingredients: ings);
    });
  }

  static Future<Recipe> getById(String id) async {
    final response = await ApiClient.dio.get('$_path/$id');
    final recipe = Recipe.fromJson(response.data as Map<String, dynamic>);

    final ingsRaw = await getIngredients(recipe.id);
    final ings = ingsRaw
        .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
        .toList();
    return recipe.copyWith(ingredients: ings);
  }

  static Future<Recipe> create(Recipe recipe) async {
    final response = await ApiClient.dio.post(_path, data: recipe.toJson());
    return Recipe.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Recipe> update(Recipe recipe) async {
    final response = await ApiClient.dio.put(
      '$_path/${recipe.id}',
      data: recipe.toJson(),
    );
    return Recipe.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> delete(String id) async {
    await ApiClient.dio.delete('$_path/$id');
  }

  // --- Recipe Ingredients ---

  static Future<List<dynamic>> getIngredients(String recipeId) async {
    final response = await ApiClient.dio.get('$_path/$recipeId/ingredients');
    return response.data as List<dynamic>;
  }

  static Future<dynamic> addIngredient(
    String recipeId,
    Map<String, dynamic> data,
  ) async {
    final response = await ApiClient.dio.post(
      '$_path/$recipeId/ingredients',
      data: data,
    );
    return response.data;
  }

  static Future<dynamic> updateIngredient(
    String recipeId,
    String riId,
    Map<String, dynamic> data,
  ) async {
    final response = await ApiClient.dio.put(
      '$_path/$recipeId/ingredients/$riId',
      data: data,
    );
    return response.data;
  }

  static Future<void> deleteIngredient(String recipeId, String riId) async {
    await ApiClient.dio.delete('$_path/$recipeId/ingredients/$riId');
  }

  /// Synchronizes a recipe and its ingredients with the backend
  static Future<void> upsert(Recipe recipe) async {
    Recipe savedRecipe;
    try {
      savedRecipe = await update(recipe);
    } catch (_) {
      savedRecipe = await create(recipe);
    }

    // Sync ingredients
    final existingIngsRaw = await getIngredients(savedRecipe.id);
    final existingIngs = existingIngsRaw
        .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
        .toList();

    // Delete removed ingredients
    for (final existing in existingIngs) {
      if (!recipe.ingredients.any((ri) => ri.id == existing.id)) {
        await deleteIngredient(savedRecipe.id, existing.id!);
      }
    }

    // Add new or update existing
    for (final ri in recipe.ingredients) {
      if (ri.id == null || ri.id!.isEmpty) {
        await addIngredient(savedRecipe.id, ri.toJson());
      } else {
        await updateIngredient(savedRecipe.id, ri.id!, ri.toJson());
      }
    }
  }
}

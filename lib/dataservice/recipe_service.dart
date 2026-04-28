import 'package:productivity/dataclasses/recipe.dart';
import 'package:productivity/dataclasses/recipe_ingredient.dart';
import 'package:productivity/dataservice/api_client.dart';

// ─────────────────────────────────────────────
//  RecipeService – API-backed
// ─────────────────────────────────────────────
class RecipeService {
  RecipeService._();

  static const String _path = '/recipes';

  /// Loads only the basic recipe data (fast)
  static Future<List<Recipe>> loadAll() async {
    final response = await ApiClient.dio.get(_path);
    final recipesRaw = response.data['items'] as List<dynamic>;

    return recipesRaw
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Loads ingredients and categories for a specific recipe
  static Future<Recipe> loadDetails(Recipe recipe) async {
    try {
      final results = await Future.wait([
        getIngredients(recipe.id),
        getCategories(recipe.id),
      ]);

      final ingsRaw = results[0] is List ? results[0] as List<dynamic> : [];
      final ings = ingsRaw
          .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
          .toList();

      final catsRaw = results[1] is List ? results[1] as List<dynamic> : [];
      final catIds = catsRaw
          .map((e) {
            final map = e as Map<String, dynamic>;
            return (map['categoryId'] ?? map['category_id'] ?? map['id'] ?? '')
                .toString();
          })
          .where((id) => id.isNotEmpty)
          .toList();

      return recipe.copyWith(ingredients: ings, categoryIds: catIds);
    } catch (e) {
      return recipe;
    }
  }

  static Future<Recipe> getById(String id) async {
    final response = await ApiClient.dio.get('$_path/$id');
    final recipe = Recipe.fromJson(response.data as Map<String, dynamic>);
    return loadDetails(recipe);
  }

  static Future<Recipe> create(Recipe recipe) async {
    final data = recipe.toJson();
    data.remove('category_ids');

    final response = await ApiClient.dio.post(_path, data: data);
    return Recipe.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Recipe> update(Recipe recipe) async {
    final data = recipe.toJson();
    data.remove('category_ids');

    final response = await ApiClient.dio.put('$_path/${recipe.id}', data: data);
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

  // --- Recipe Categories ---

  static Future<List<dynamic>> getCategories(String recipeId) async {
    final response = await ApiClient.dio.get('$_path/$recipeId/categories');
    return response.data as List<dynamic>;
  }

  static Future<void> syncCategories(
    String recipeId,
    List<String> categoryIds,
  ) async {
    final currentCatsRaw = await getCategories(recipeId);
    final currentCatIds = (currentCatsRaw)
        .map((e) {
          final map = e as Map<String, dynamic>;
          return (map['categoryId'] ?? map['category_id'] ?? map['id'] ?? '')
              .toString();
        })
        .where((id) => id.isNotEmpty)
        .toList();

    for (final existingId in currentCatIds) {
      if (!categoryIds.contains(existingId)) {
        try {
          await ApiClient.dio.delete('$_path/$recipeId/categories/$existingId');
        } catch (e) {
          // Category deletion failed silently
        }
      }
    }

    for (final newId in categoryIds) {
      if (!currentCatIds.contains(newId)) {
        await ApiClient.dio.post(
          '$_path/$recipeId/categories',
          data: {'categoryId': newId},
        );
      }
    }
  }

  /// Synchronizes a recipe and its ingredients/categories with the backend
  static Future<void> upsert(Recipe recipe) async {
    Recipe savedRecipe;

    try {
      savedRecipe = await update(recipe);
    } catch (e) {
      savedRecipe = await create(recipe);
    }

    await syncCategories(savedRecipe.id, recipe.categoryIds);

    final existingIngsRaw = await getIngredients(savedRecipe.id);
    final existingIngs = existingIngsRaw
        .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
        .toList();

    for (final existing in existingIngs) {
      if (!recipe.ingredients.any((ri) => ri.id == existing.id)) {
        await deleteIngredient(savedRecipe.id, existing.id!);
      }
    }

    for (final ri in recipe.ingredients) {
      if (ri.id == null || ri.id!.isEmpty) {
        await addIngredient(savedRecipe.id, ri.toJson());
      } else {
        await updateIngredient(savedRecipe.id, ri.id!, ri.toJson());
      }
    }
  }
}

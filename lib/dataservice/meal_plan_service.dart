import 'package:productivity/dataclasses/meal_plan.dart';
import 'package:productivity/dataclasses/shopping_suggestion.dart';
import 'package:productivity/dataservice/api_client.dart';
import 'package:productivity/dataservice/haushalt_sicht.dart';

class MealPlanService {
  MealPlanService._();

  static const String _path = '/meal-plan';

  /// [bereich] ist die Umschaltung „Alles / Meins / Unseres".
  static Future<List<MealPlanEntry>> loadAll(
      {Bereich bereich = Bereich.alles}) async {
    final response = await ApiClient.dio.get(
      _path,
      queryParameters: bereich.abfrage.isEmpty ? null : bereich.abfrage,
    );
    // API returns {"total": X, "items": [...]}
    final list = response.data['items'] as List<dynamic>;
    return list.map((e) => MealPlanEntry.fromJson(e)).toList();
  }

  static Future<MealPlanEntry> upsert(MealPlanEntry entry,
      {bool unseres = false}) async {
    if (entry.id.isEmpty) {
      final response = await ApiClient.dio
          .post(_path, data: {...entry.toJson(), 'unseres': unseres});
      return MealPlanEntry.fromJson(response.data);
    } else {
      final response = await ApiClient.dio.put('$_path/${entry.id}', data: entry.toJson());
      return MealPlanEntry.fromJson(response.data);
    }
  }

  /// „Das planen wir gemeinsam." Oder eben doch nicht.
  static Future<MealPlanEntry> zuordnen(String id, bool unseres) async {
    final r = await ApiClient.dio
        .put('$_path/$id/haushalt', data: {'unseres': unseres});
    return MealPlanEntry.fromJson(r.data);
  }

  static Future<void> delete(String id) async {
    await ApiClient.dio.delete('$_path/$id');
  }

  /// Schlägt anhand der geplanten Rezepte im Zeitraum vor, was eingekauft
  /// werden muss – Bedarf summiert, vorhandener Vorrat abgezogen.
  static Future<List<ShoppingSuggestion>> shoppingSuggestions({
    required DateTime from,
    required DateTime to,
  }) async {
    String tag(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    final response = await ApiClient.dio.get(
      '$_path/shopping-list',
      queryParameters: {'date_from': tag(from), 'date_to': tag(to)},
    );
    return (response.data['items'] as List<dynamic>)
        .map((e) => ShoppingSuggestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

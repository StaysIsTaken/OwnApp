import 'dart:convert';

// ─────────────────────────────────────────────
//  Ingredient (Zutat)
//  Carries a defaultUnitId that is pre-selected
//  when the ingredient is added to a recipe.
// ─────────────────────────────────────────────
class Ingredient {
  final String id;
  final String name;
  final String? defaultUnitId;

  const Ingredient({required this.id, required this.name, this.defaultUnitId});

  Ingredient copyWith({String? id, String? name, String? defaultUnitId}) =>
      Ingredient(
        id: id ?? this.id,
        name: name ?? this.name,
        defaultUnitId: defaultUnitId ?? this.defaultUnitId,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'unitId': defaultUnitId, // redundanter Fallback
  };

  factory Ingredient.fromJson(Map<String, dynamic> j) {
    // Try to find the unit ID in various places (flat or nested)
    dynamic rawUnit =
        j['unit'] ??
        j['default_unit'] ??
        j['defaultUnit'] ??
        j['unitId'] ??
        j['unit_id'] ??
        j['defaultUnitId'] ??
        j['default_unit_id'];

    String? extractedId;
    if (rawUnit is Map) {
      extractedId =
          (rawUnit['id'] ?? rawUnit['categoryId'] ?? rawUnit['unitId'])
              ?.toString();
    } else {
      extractedId = rawUnit?.toString();
    }

    return Ingredient(
      id: j['id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      defaultUnitId: extractedId,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Ingredient.fromJsonString(String s) =>
      Ingredient.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

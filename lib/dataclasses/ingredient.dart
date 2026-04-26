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

  const Ingredient({
    required this.id,
    required this.name,
    this.defaultUnitId,
  });

  Ingredient copyWith({String? id, String? name, String? defaultUnitId}) =>
      Ingredient(
        id: id ?? this.id,
        name: name ?? this.name,
        defaultUnitId: defaultUnitId ?? this.defaultUnitId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'defaultUnitId': defaultUnitId,
      };

  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        defaultUnitId: j['defaultUnitId']?.toString(),
      );

  String toJsonString() => jsonEncode(toJson());

  factory Ingredient.fromJsonString(String s) =>
      Ingredient.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

import 'dart:convert';

// ─────────────────────────────────────────────
//  Category – Recipe category
// ─────────────────────────────────────────────
class Category {
  final String id;
  final String name;

  const Category({required this.id, required this.name});

  Category copyWith({String? id, String? name}) => Category(
        id: id ?? this.id,
        name: name ?? this.name,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as String,
        name: j['name'] as String,
      );

  String toJsonString() => jsonEncode(toJson());

  factory Category.fromJsonString(String s) =>
      Category.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

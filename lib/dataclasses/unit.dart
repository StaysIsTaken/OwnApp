import 'dart:convert';

// ─────────────────────────────────────────────
//  Unit (Einheit) – e.g. "Gramm" / "g"
// ─────────────────────────────────────────────
class Unit {
  final String id;
  final String name;   // "Gramm"
  final String symbol; // "g"

  const Unit({required this.id, required this.name, required this.symbol});

  Unit copyWith({String? id, String? name, String? symbol}) => Unit(
        id: id ?? this.id,
        name: name ?? this.name,
        symbol: symbol ?? this.symbol,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'symbol': symbol};

  factory Unit.fromJson(Map<String, dynamic> j) => Unit(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        symbol: j['symbol']?.toString() ?? '',
      );

  String toJsonString() => jsonEncode(toJson());

  factory Unit.fromJsonString(String s) =>
      Unit.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

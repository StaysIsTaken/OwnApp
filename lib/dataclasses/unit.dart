import 'dart:convert';

// ─────────────────────────────────────────────
//  Unit (Einheit) – e.g. "Gramm" / "g"
// ─────────────────────────────────────────────

/// Dimension einer Einheit. Umgerechnet wird nur innerhalb derselben
/// Dimension – Masse gegen Volumen bräuchte die Dichte der Zutat.
enum UnitDimension {
  mass('mass', 'Masse', 'g'),
  volume('volume', 'Volumen', 'ml'),
  count('count', 'Stückzahl', 'Stk');

  const UnitDimension(this.apiValue, this.label, this.baseSymbol);

  final String apiValue;
  final String label;

  /// Basiseinheit, auf die sich `Unit.factor` bezieht.
  final String baseSymbol;

  static UnitDimension? fromApi(String? v) {
    if (v == null || v.isEmpty) return null;
    for (final d in values) {
      if (d.apiValue == v) return d;
    }
    return null;
  }
}

class Unit {
  final String id;
  final String name; // "Gramm"
  final String symbol; // "g"

  /// null = nicht umrechenbar (die Einheit zählt dann nur gegen sich selbst).
  final UnitDimension? dimension;

  /// Wie viele Basiseinheiten der Dimension eine Einheit ausmacht: kg = 1000.
  final double factor;

  const Unit({
    required this.id,
    required this.name,
    required this.symbol,
    this.dimension,
    this.factor = 1.0,
  });

  Unit copyWith({
    String? id,
    String? name,
    String? symbol,
    UnitDimension? dimension,
    bool clearDimension = false,
    double? factor,
  }) =>
      Unit(
        id: id ?? this.id,
        name: name ?? this.name,
        symbol: symbol ?? this.symbol,
        dimension: clearDimension ? null : (dimension ?? this.dimension),
        factor: factor ?? this.factor,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'symbol': symbol,
        'dimension': dimension?.apiValue,
        'factor': factor,
      };

  factory Unit.fromJson(Map<String, dynamic> j) => Unit(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        symbol: j['symbol']?.toString() ?? '',
        dimension: UnitDimension.fromApi(j['dimension']?.toString()),
        factor: (j['factor'] as num?)?.toDouble() ?? 1.0,
      );

  String toJsonString() => jsonEncode(toJson());

  factory Unit.fromJsonString(String s) =>
      Unit.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

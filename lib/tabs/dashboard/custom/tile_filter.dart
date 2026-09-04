/// Benutzerdefinierte Filter für Kachel-Daten.
///
/// Läuft bewusst im Client: die Kacheln rechnen ohnehin aus bereits geladenen
/// Daten. Serverseitige Filter hätten eine eigene Abfragesprache gebraucht —
/// viel Arbeit und eine ernste Angriffsfläche auf einer geteilten Datenbank.
library;

/// Datentyp eines filterbaren Feldes. Bestimmt, welche Operatoren angeboten
/// werden und wie der Wert eingegeben wird.
enum FieldType {
  number,
  text,
  date,
  boolean,

  /// Feste Auswahl (z.B. Kanban-Spalte) – Wert kommt aus einer Liste.
  choice,
}

/// Vergleichsoperatoren. Welche zu einem Typ passen, sagt [operatorsFor].
enum FilterOp {
  equals,
  notEquals,
  greater,
  greaterOrEqual,
  less,
  lessOrEqual,
  contains,
  startsWith,
  isTrue,
  isFalse,
  lastDays,
}

extension FilterOpLabel on FilterOp {
  String get label {
    switch (this) {
      case FilterOp.equals:
        return 'ist gleich';
      case FilterOp.notEquals:
        return 'ist nicht';
      case FilterOp.greater:
        return 'größer als';
      case FilterOp.greaterOrEqual:
        return 'größer oder gleich';
      case FilterOp.less:
        return 'kleiner als';
      case FilterOp.lessOrEqual:
        return 'kleiner oder gleich';
      case FilterOp.contains:
        return 'enthält';
      case FilterOp.startsWith:
        return 'beginnt mit';
      case FilterOp.isTrue:
        return 'ist ja';
      case FilterOp.isFalse:
        return 'ist nein';
      case FilterOp.lastDays:
        return 'in den letzten … Tagen';
    }
  }

  /// Braucht dieser Operator überhaupt einen Wert?
  bool get needsValue => this != FilterOp.isTrue && this != FilterOp.isFalse;

  String get apiValue => name;

  static FilterOp? fromApi(String? v) {
    for (final o in FilterOp.values) {
      if (o.name == v) return o;
    }
    return null;
  }
}

/// Welche Operatoren zu einem Feldtyp passen.
///
/// Damit kann im Editor keine unsinnige Kombination entstehen, ohne dass
/// irgendwo eine Tabelle erlaubter Paarungen gepflegt werden müsste.
List<FilterOp> operatorsFor(FieldType type) {
  switch (type) {
    case FieldType.number:
      return const [
        FilterOp.equals, FilterOp.notEquals, FilterOp.greater,
        FilterOp.greaterOrEqual, FilterOp.less, FilterOp.lessOrEqual,
      ];
    case FieldType.text:
      return const [
        FilterOp.contains, FilterOp.startsWith,
        FilterOp.equals, FilterOp.notEquals,
      ];
    case FieldType.date:
      return const [
        FilterOp.lastDays, FilterOp.greater, FilterOp.less, FilterOp.equals,
      ];
    case FieldType.boolean:
      return const [FilterOp.isTrue, FilterOp.isFalse];
    case FieldType.choice:
      return const [FilterOp.equals, FilterOp.notEquals];
  }
}

/// Ein filterbares Feld einer Datenquelle.
class FilterField {
  final String key;
  final String label;
  final FieldType type;

  /// Liest den Wert aus einem Datensatz. Gibt null zurück, wenn er fehlt.
  final Object? Function(dynamic item) read;

  /// Nur bei [FieldType.choice]: die auswählbaren Werte.
  final List<String> choices;

  const FilterField({
    required this.key,
    required this.label,
    required this.type,
    required this.read,
    this.choices = const [],
  });
}

/// Eine vom Nutzer gesetzte Bedingung.
class FilterRule {
  final String field;
  final FilterOp op;
  final String value;

  const FilterRule({required this.field, required this.op, this.value = ''});

  Map<String, dynamic> toJson() =>
      {'field': field, 'op': op.apiValue, 'value': value};

  static FilterRule? fromJson(Map<String, dynamic> j) {
    final op = FilterOpLabel.fromApi(j['op']?.toString());
    final field = j['field']?.toString();
    if (op == null || field == null || field.isEmpty) return null;
    return FilterRule(field: field, op: op, value: j['value']?.toString() ?? '');
  }
}

/// Wendet die Regeln an. Alle müssen zutreffen (UND).
///
/// Bewusst kein ODER und keine Klammern: das wäre der Schritt von „Filter" zu
/// „Abfragesprache", und in einer Haushalts-App reicht die Verkettung.
List<T> applyFilters<T>(
  List<T> items,
  List<FilterRule> rules,
  Map<String, FilterField> fields,
) {
  if (rules.isEmpty) return items;
  return items.where((item) {
    for (final r in rules) {
      final f = fields[r.field];
      // Unbekanntes Feld (z.B. aus einer neueren Version): Regel ignorieren,
      // statt alles wegzufiltern.
      if (f == null) continue;
      if (!_matches(f.read(item), f.type, r)) return false;
    }
    return true;
  }).toList();
}

bool _matches(Object? wert, FieldType type, FilterRule r) {
  switch (type) {
    case FieldType.boolean:
      final b = wert == true;
      return r.op == FilterOp.isTrue ? b : !b;

    case FieldType.number:
      final a = _alsZahl(wert);
      final b = double.tryParse(r.value.replaceAll(',', '.'));
      if (a == null || b == null) return false;
      return _vergleiche(a.compareTo(b), r.op);

    case FieldType.date:
      final d = wert is DateTime ? wert : null;
      if (d == null) return false;
      if (r.op == FilterOp.lastDays) {
        final tage = int.tryParse(r.value) ?? 0;
        if (tage <= 0) return false;
        final ab = DateTime.now().subtract(Duration(days: tage));
        return d.isAfter(ab);
      }
      final b = DateTime.tryParse(r.value);
      if (b == null) return false;
      if (r.op == FilterOp.equals) {
        return d.year == b.year && d.month == b.month && d.day == b.day;
      }
      return _vergleiche(d.compareTo(b), r.op);

    case FieldType.text:
    case FieldType.choice:
      final a = (wert?.toString() ?? '').toLowerCase();
      final b = r.value.toLowerCase();
      switch (r.op) {
        case FilterOp.contains:
          return a.contains(b);
        case FilterOp.startsWith:
          return a.startsWith(b);
        case FilterOp.equals:
          return a == b;
        case FilterOp.notEquals:
          return a != b;
        default:
          return false;
      }
  }
}

bool _vergleiche(int c, FilterOp op) {
  switch (op) {
    case FilterOp.equals:
      return c == 0;
    case FilterOp.notEquals:
      return c != 0;
    case FilterOp.greater:
      return c > 0;
    case FilterOp.greaterOrEqual:
      return c >= 0;
    case FilterOp.less:
      return c < 0;
    case FilterOp.lessOrEqual:
      return c <= 0;
    default:
      return false;
  }
}

double? _alsZahl(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.'));
  return null;
}

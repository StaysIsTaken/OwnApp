import 'package:productivity/tabs/dashboard/custom/tile_data.dart';
import 'package:productivity/tabs/dashboard/custom/tile_filter.dart';

/// Was der Nutzer beim Anlegen einer Kachel zusammenstellt.
class CustomTile {
  final String id;
  final String source;
  final String view;
  final String? title;
  final Map<String, dynamic> params;
  final List<FilterRule> filters;

  const CustomTile({
    required this.id,
    required this.source,
    required this.view,
    this.title,
    this.params = const {},
    this.filters = const [],
  });

  CustomTile copyWith({
    String? title,
    Map<String, dynamic>? params,
    List<FilterRule>? filters,
  }) =>
      CustomTile(
        id: id,
        source: source,
        view: view,
        title: title ?? this.title,
        params: params ?? this.params,
        filters: filters ?? this.filters,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source,
        'view': view,
        'title': title,
        'params': params,
        'filters': filters.map((f) => f.toJson()).toList(),
      };

  factory CustomTile.fromJson(Map<String, dynamic> j) {
    final regeln = <FilterRule>[];
    for (final e in (j['filters'] as List<dynamic>? ?? const [])) {
      // Kaputte oder unbekannte Regeln überspringen statt zu werfen —
      // sonst würde eine Kachel aus einer neueren Version die App zerlegen.
      final r = FilterRule.fromJson((e as Map).cast<String, dynamic>());
      if (r != null) regeln.add(r);
    }
    return CustomTile(
      id: j['id']?.toString() ?? '',
      source: j['source']?.toString() ?? '',
      view: j['view']?.toString() ?? '',
      title: j['title']?.toString(),
      params: (j['params'] as Map?)?.cast<String, dynamic>() ?? const {},
      filters: regeln,
    );
  }
}

/// Ein einstellbarer Wert einer Quelle (z.B. „letzte N Tage").
class TileParam {
  final String key;
  final String label;
  final int min;
  final int max;
  final int standard;

  const TileParam({
    required this.key,
    required this.label,
    required this.min,
    required this.max,
    required this.standard,
  });
}

/// Eine Datenquelle im Katalog.
///
/// `build` bekommt alles, was das Dashboard ohnehin geladen hat, und formt
/// daraus eine [TileData]. Neue Quelle heißt: einen Eintrag ergänzen — die
/// Oberfläche bietet sie danach automatisch an.
class TileSource {
  final String key;
  final String label;
  final String group;
  final TileShape shape;
  final List<TileParam> params;

  /// Wohin ein Tippen auf die Kachel führt (Route aus `AppRoutes`).
  /// Null = die Kachel ist nicht anklickbar.
  final String? route;

  /// Felder, nach denen gefiltert werden kann – Schlüssel → Feld.
  final Map<String, FilterField> fields;

  final TileData Function(
    DashboardData data,
    Map<String, dynamic> params,
    List<FilterRule> filters,
  ) build;

  const TileSource({
    required this.key,
    required this.label,
    required this.group,
    required this.shape,
    required this.build,
    this.params = const [],
    this.route,
    this.fields = const {},
  });

  bool get filterable => fields.isNotEmpty;
}

/// Alles, was das Dashboard geladen hat – der Eingang für jede Quelle.
///
/// Bewusst ein einfacher Behälter statt einzelner Parameter: kommt eine neue
/// Quelle dazu, die andere Daten braucht, wächst nur diese Klasse.
class DashboardData {
  final List<dynamic> tasks;
  final List<dynamic> timeEntries;
  final List<dynamic> plannerEntries;
  final List<dynamic> shoppingItems;
  final List<dynamic> pantryItems;
  final List<dynamic> notes;
  final List<dynamic> journalEntries;
  final Map<String, dynamic> sentimentStats;
  final Map<String, dynamic> ingredientMap;

  const DashboardData({
    this.tasks = const [],
    this.timeEntries = const [],
    this.plannerEntries = const [],
    this.shoppingItems = const [],
    this.pantryItems = const [],
    this.notes = const [],
    this.journalEntries = const [],
    this.sentimentStats = const {},
    this.ingredientMap = const {},
  });
}

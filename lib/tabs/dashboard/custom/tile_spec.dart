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

  /// Wo die Kachel liegt: `kopf` (volle Breite, über der Übersicht) oder
  /// `raster`. Getrennt, weil ein Block ganz oben anders wirkt als ein
  /// Kärtchen im dreispaltigen Raster – und weil man ihn dort auch anders
  /// bauen will.
  final String zone;

  static const String zoneKopf = 'kopf';
  static const String zoneRaster = 'raster';

  const CustomTile({
    required this.id,
    required this.source,
    required this.view,
    this.title,
    this.params = const {},
    this.filters = const [],
    this.zone = zoneRaster,
  });

  bool get imKopf => zone == zoneKopf;

  CustomTile copyWith({
    String? title,
    Map<String, dynamic>? params,
    List<FilterRule>? filters,
    String? zone,
  }) =>
      CustomTile(
        id: id,
        source: source,
        view: view,
        title: title ?? this.title,
        params: params ?? this.params,
        filters: filters ?? this.filters,
        zone: zone ?? this.zone,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source,
        'view': view,
        'title': title,
        'params': params,
        'filters': filters.map((f) => f.toJson()).toList(),
        'zone': zone,
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
      // Ohne Angabe im Raster: so bleiben Kacheln aus der Zeit vor den
      // Kopfbloecken dort, wo sie waren.
      zone: j['zone']?.toString() == zoneKopf ? zoneKopf : zoneRaster,
    );
  }
}

/// Was für eine Eingabe eine Einstellung braucht.
///
/// Bisher waren alle Einstellungen Zahlen mit Plus/Minus. Für eigene
/// Blöcke reicht das nicht: ein Text will getippt, ein Datum gewählt
/// werden. Die Oberfläche entscheidet daran, welches Feld sie zeigt.
enum ParamArt { zahl, text, mehrzeilig, datum }

/// Ein einstellbarer Wert einer Quelle (z.B. „letzte N Tage").
class TileParam {
  final String key;
  final String label;
  final ParamArt art;

  /// Nur für [ParamArt.zahl].
  final int min;
  final int max;
  final int standard;

  /// Nur für Text: was blass im leeren Feld steht.
  final String? platzhalter;

  const TileParam({
    required this.key,
    required this.label,
    this.art = ParamArt.zahl,
    this.min = 0,
    this.max = 0,
    this.standard = 0,
    this.platzhalter,
  });

  const TileParam.text({
    required this.key,
    required this.label,
    this.platzhalter,
    this.art = ParamArt.text,
  })  : min = 0,
        max = 0,
        standard = 0;

  const TileParam.mehrzeilig({
    required this.key,
    required this.label,
    this.platzhalter,
  })  : art = ParamArt.mehrzeilig,
        min = 0,
        max = 0,
        standard = 0;

  const TileParam.datum({required this.key, required this.label})
      : art = ParamArt.datum,
        min = 0,
        max = 0,
        standard = 0,
        platzhalter = null;
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

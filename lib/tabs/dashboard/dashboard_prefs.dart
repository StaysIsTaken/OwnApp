import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:productivity/dataservice/dashboard_layout_service.dart';
import 'package:productivity/tabs/dashboard/custom/tile_spec.dart';
import 'package:productivity/tabs/dashboard/seiten_einstellungen.dart';

/// Der komplette Stand einer Seite: Reihenfolge, Ausgeblendetes, eigene
/// Kacheln und was für die ganze Seite gilt.
///
/// Als benannter Typ statt eines anonymen Datensatzes, weil er inzwischen
/// an vier Stellen auftaucht — und weil ein fünftes Feld sonst jede davon
/// anfasst.
typedef Seitenstand = ({
  List<String> order,
  Set<String> hidden,
  List<CustomTile> tiles,
  SeitenEinstellungen einstellungen,
});

/// Anordnung der Kacheln einer Übersichtsseite.
///
/// Die Einstellung gehört zum Konto, nicht zum Gerät — deshalb liegt sie im
/// Backend. Damit die Seite trotzdem immer erscheint, gibt es drei Stufen:
///
///   1. Backend — der maßgebliche Stand, gilt auf allen Geräten
///   2. Lokaler Cache — was zuletzt geladen wurde; greift bei Ausfall,
///      Zeitüberschreitung und offline
///   3. Standard aus dem Code — wenn noch nie etwas geladen wurde
///
/// Gespeichert wird immer beides: Backend und Cache. Der Cache ist damit
/// nicht nur Rückfall, sondern sorgt auch dafür, dass die Seite beim
/// nächsten Start sofort richtig aussieht, ohne aufs Netz zu warten.
class DashboardPrefs {
  DashboardPrefs._();

  /// Die beiden Übersichtsseiten. Muss zu `BEKANNTE_SEITEN` im Backend passen.
  static const String keyDashboard = 'dashboard';
  static const String keyHome = 'home';

  /// Die Karten über der Übersicht. Sie liegen in derselben gespeicherten
  /// Reihenfolge wie die übrigen, werden aber in voller Breite gezeigt und
  /// bleiben unter sich: eine Begrüßung im dreispaltigen Raster sähe
  /// merkwürdig aus, und ein Aufgaben-Kärtchen über der Begrüßung ebenso.
  static const List<String> kopfSchluessel = [
    'greeting', 'quickactions', 'todayfocus', 'agenda',
  ];

  static bool istKopf(String schluessel) => kopfSchluessel.contains(schluessel);

  /// Kacheln je Seite, in Standardreihenfolge.
  static const Map<String, List<String>> _defaults = {
    keyDashboard: [
      'greeting', 'quickactions', 'todayfocus', 'agenda',
      'tasks', 'time', 'shopping', 'pantry', 'mealplan', 'journal', 'notes',
    ],
    keyHome: [
      'taskstats', 'tasksdue', 'shopping', 'pantry',
    ],
  };

  static const Map<String, String> labels = {
    // Kopfbereich
    'greeting': 'Begrüßung',
    'quickactions': 'Schnellzugriff',
    'todayfocus': 'Heute im Blick',
    'agenda': 'Heutige Termine',
    // Dashboard
    'tasks': 'Aufgaben',
    'time': 'Zeit',
    'shopping': 'Einkauf',
    'pantry': 'Vorräte',
    'mealplan': 'Essensplan',
    'journal': 'Journal',
    'notes': 'Notizen',
    // Home
    'taskstats': 'Aufgaben-Überblick',
    'tasksdue': 'Heute fällig',
  };

  static List<String> defaultOrder(String dashboardKey) =>
      List<String>.from(_defaults[dashboardKey] ?? const []);

  static String _orderKey(String d) => 'dash_order_v2_$d';
  static String _hiddenKey(String d) => 'dash_hidden_v2_$d';
  static String _tilesKey(String d) => 'dash_tiles_v2_$d';
  static String _settingsKey(String d) => 'dash_settings_v2_$d';

  // ── Laden ────────────────────────────────────────────────────────────────

  /// Holt die Anordnung. Fällt bei jedem Problem lautlos auf die nächste
  /// Stufe zurück — die Übersichtsseite soll immer erscheinen.
  static Future<Seitenstand> load(String dashboardKey) async {
    try {
      final remote = await DashboardLayoutService.load(dashboardKey);
      if (remote.configured) {
        await _cache(dashboardKey, remote.order, remote.hidden, remote.tiles,
            remote.einstellungen);
        return (
          order: _normalize(dashboardKey, remote.order, remote.tiles),
          hidden: remote.hidden,
          tiles: remote.tiles,
          einstellungen: remote.einstellungen,
        );
      }
      // Noch nie eingerichtet: Standard, aber kein Fehler.
      return (
        order: defaultOrder(dashboardKey),
        hidden: <String>{},
        tiles: <CustomTile>[],
        einstellungen: SeitenEinstellungen.leer,
      );
    } catch (_) {
      // Netz weg, zu langsam, Server kaputt — der lokale Stand tut es auch.
      return _loadCached(dashboardKey);
    }
  }

  static Future<Seitenstand> _loadCached(String dashboardKey) async {
    final leer = (
      order: defaultOrder(dashboardKey),
      hidden: <String>{},
      tiles: <CustomTile>[],
      einstellungen: SeitenEinstellungen.leer,
    );
    try {
      final p = await SharedPreferences.getInstance();
      final order = p.getStringList(_orderKey(dashboardKey));
      if (order == null) return leer;

      final roh = p.getString(_tilesKey(dashboardKey));
      final tiles = <CustomTile>[];
      if (roh != null && roh.isNotEmpty) {
        for (final e in (jsonDecode(roh) as List<dynamic>)) {
          tiles.add(CustomTile.fromJson(e as Map<String, dynamic>));
        }
      }
      final rohEinst = p.getString(_settingsKey(dashboardKey));
      return (
        order: _normalize(dashboardKey, order, tiles),
        hidden: (p.getStringList(_hiddenKey(dashboardKey)) ?? const []).toSet(),
        tiles: tiles,
        einstellungen: rohEinst == null || rohEinst.isEmpty
            ? SeitenEinstellungen.leer
            : SeitenEinstellungen.fromJson(
                (jsonDecode(rohEinst) as Map).cast<String, dynamic>()),
      );
    } catch (_) {
      return leer;
    }
  }

  // ── Speichern ────────────────────────────────────────────────────────────

  /// Speichert im Backend und lokal. Schlägt das Backend fehl, bleibt die
  /// Änderung wenigstens auf diesem Gerät erhalten — deshalb wird der Cache
  /// zuerst geschrieben.
  ///
  /// Gibt zurück, ob das Backend erreicht wurde.
  static Future<bool> save(
    String dashboardKey,
    List<String> order,
    Set<String> hidden, {
    List<CustomTile> tiles = const [],
    SeitenEinstellungen einstellungen = SeitenEinstellungen.leer,
  }) async {
    await _cache(dashboardKey, order, hidden, tiles, einstellungen);
    try {
      await DashboardLayoutService.save(
        dashboardKey,
        order: order,
        hidden: hidden,
        tiles: tiles,
        einstellungen: einstellungen,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _cache(
    String dashboardKey,
    List<String> order,
    Set<String> hidden,
    List<CustomTile> tiles,
    SeitenEinstellungen einstellungen,
  ) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_orderKey(dashboardKey), order);
      await p.setStringList(_hiddenKey(dashboardKey), hidden.toList());
      await p.setString(_tilesKey(dashboardKey),
          jsonEncode(tiles.map((t) => t.toJson()).toList()));
      await p.setString(
          _settingsKey(dashboardKey), jsonEncode(einstellungen.toJson()));
    } catch (_) {
      // Kein lokaler Speicher (z.B. eingeschränkter Browser) — nicht schlimm.
    }
  }

  /// Setzt auf die Standardanordnung zurück.
  static Future<void> reset(String dashboardKey) async {
    try {
      await DashboardLayoutService.reset(dashboardKey);
    } catch (_) {
      // Auch ohne Backend lokal zurücksetzen.
    }
    await _cache(dashboardKey, defaultOrder(dashboardKey), <String>{}, const [],
        SeitenEinstellungen.leer);
  }

  // ── Hilfen ───────────────────────────────────────────────────────────────

  /// Bringt eine gespeicherte Reihenfolge mit den heute bekannten Kacheln in
  /// Einklang: Unbekanntes fliegt raus, Neues wird hinten angehängt.
  ///
  /// Ohne das würde eine ältere gespeicherte Anordnung eine neu
  /// hinzugekommene Kachel dauerhaft verstecken.
  static List<String> _normalize(
    String dashboardKey,
    List<String> saved,
    List<CustomTile> tiles,
  ) {
    // Eigene Kacheln gehören genauso in die Reihenfolge wie die fest
    // eingebauten – sonst rutschten sie bei jedem Laden ans Ende.
    final bekannt = [...defaultOrder(dashboardKey), ...tiles.map((t) => t.id)];
    final result = <String>[];
    for (final k in saved) {
      if (bekannt.contains(k) && !result.contains(k)) result.add(k);
    }
    for (final k in bekannt) {
      if (!result.contains(k)) result.add(k);
    }
    return result;
  }
}

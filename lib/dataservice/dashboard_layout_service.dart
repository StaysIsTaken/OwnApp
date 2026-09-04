import 'package:productivity/dataservice/api_client.dart';
import 'package:productivity/tabs/dashboard/custom/tile_spec.dart';
import 'package:productivity/tabs/dashboard/seiten_einstellungen.dart';

/// Anordnung einer Übersichtsseite, wie sie vom Backend kommt.
class DashboardLayout {
  final List<String> order;
  final Set<String> hidden;
  final List<CustomTile> tiles;

  /// Was für die ganze Seite gilt – etwa welche Kalender sie zeigt.
  final SeitenEinstellungen einstellungen;

  /// False = für diesen Nutzer wurde noch nie etwas gespeichert.
  /// Dann gilt die Standardanordnung, nicht "alles ausgeblendet".
  final bool configured;

  const DashboardLayout({
    required this.order,
    required this.hidden,
    required this.configured,
    this.tiles = const [],
    this.einstellungen = SeitenEinstellungen.leer,
  });

  static const empty =
      DashboardLayout(order: [], hidden: {}, configured: false);
}

class DashboardLayoutService {
  DashboardLayoutService._();

  static const String _path = '/dashboard-layout';

  /// Wie lange auf das Backend gewartet wird, bevor auf den lokalen Stand
  /// zurückgefallen wird. Kurz gehalten: die Übersichtsseite ist das Erste,
  /// was man sieht — sie darf nicht auf ein Netzwerk-Zeitlimit warten.
  static const Duration timeout = Duration(seconds: 3);

  static Future<DashboardLayout> load(String dashboardKey) async {
    final response = await ApiClient.dio
        .get('$_path/$dashboardKey')
        .timeout(timeout);
    final d = response.data as Map<String, dynamic>;
    return DashboardLayout(
      order: (d['order'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      hidden: (d['hidden'] as List<dynamic>? ?? []).map((e) => e.toString()).toSet(),
      configured: d['configured'] == true,
      tiles: (d['tiles'] as List<dynamic>? ?? [])
          .map((e) => CustomTile.fromJson(e as Map<String, dynamic>))
          .toList(),
      einstellungen: SeitenEinstellungen.fromJson(
          (d['settings'] as Map?)?.cast<String, dynamic>()),
    );
  }

  static Future<void> save(
    String dashboardKey, {
    required List<String> order,
    required Set<String> hidden,
    List<CustomTile> tiles = const [],
    SeitenEinstellungen einstellungen = SeitenEinstellungen.leer,
  }) async {
    await ApiClient.dio.put(
      '$_path/$dashboardKey',
      data: {
        'order': order,
        'hidden': hidden.toList(),
        'tiles': tiles.map((t) => t.toJson()).toList(),
        'settings': einstellungen.toJson(),
      },
    );
  }

  static Future<void> reset(String dashboardKey) async {
    await ApiClient.dio.delete('$_path/$dashboardKey');
  }
}

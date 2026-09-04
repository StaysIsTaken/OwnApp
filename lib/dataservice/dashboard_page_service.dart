import 'package:productivity/dataclasses/dashboard_page.dart';
import 'package:productivity/dataservice/api_client.dart';

/// Übersichtsseiten: auflisten, anlegen, umbenennen, löschen.
class DashboardPageService {
  DashboardPageService._();

  static const String _pfad = '/dashboard-pages';

  static Future<List<DashboardSeite>> laden({String? mode}) async {
    final r = await ApiClient.dio.get(
      _pfad,
      queryParameters: mode == null ? null : {'mode': mode},
    );
    return (r.data as List<dynamic>)
        .map((e) => DashboardSeite.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<DashboardSeite> anlegen({
    required String name,
    String mode = DashboardSeite.modeApp,
    String? icon,
  }) async {
    final daten = <String, dynamic>{'name': name, 'mode': mode};
    if (icon != null) daten['icon'] = icon;
    final r = await ApiClient.dio.post(_pfad, data: daten);
    return DashboardSeite.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<DashboardSeite> umbenennen(int id, String name) async {
    final r = await ApiClient.dio.put('$_pfad/$id', data: {'name': name});
    return DashboardSeite.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<void> loeschen(int id) => ApiClient.dio.delete('$_pfad/$id');
}

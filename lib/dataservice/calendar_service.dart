import 'package:productivity/dataclasses/kalender.dart';
import 'package:productivity/dataservice/api_client.dart';

/// Kalender: auflisten, anlegen, ändern, löschen, abholen.
class CalendarService {
  CalendarService._();

  static const String _pfad = '/calendars';

  /// Die eigenen Kalender — mit [alle] auch die der übrigen Personen.
  ///
  /// [alle] verlangt das Recht `planner:read_all` und ist bewusst ein
  /// ausdrücklicher Schalter: das Küchen-Tablet setzt ihn, dasselbe Konto
  /// am Telefon nicht.
  static Future<List<Kalender>> laden({bool alle = false}) async {
    final r = await ApiClient.dio.get(
      _pfad,
      queryParameters: alle ? {'alle': true} : null,
    );
    return (r.data as List<dynamic>)
        .map((e) => Kalender.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Kalender> anlegen({
    required String name,
    String color = '#3B82F6',
    String? icon,
    String? icsUrl,
  }) async {
    final r = await ApiClient.dio.post(_pfad, data: {
      'name': name,
      'color': color,
      'icon': ?icon,
      if (icsUrl != null && icsUrl.isNotEmpty) 'ics_url': icsUrl,
    });
    return Kalender.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<Kalender> aendern(
    int id, {
    String? name,
    String? color,
    String? icon,
    String? icsUrl,
  }) async {
    final r = await ApiClient.dio.put('$_pfad/$id', data: {
      'name': ?name,
      'color': ?color,
      'icon': ?icon,
      'ics_url': ?icsUrl,
    });
    return Kalender.fromJson(r.data as Map<String, dynamic>);
  }

  /// Holt die hinterlegte Adresse sofort — nützlich direkt nach dem
  /// Eintragen, um zu sehen, ob sie stimmt.
  static Future<Map<String, dynamic>> abholen(int id) async {
    final r = await ApiClient.dio.post('$_pfad/$id/sync');
    return (r.data as Map).cast<String, dynamic>();
  }

  /// Löscht den Kalender, **nicht** die Termine darin — die verlieren nur
  /// ihre Zuordnung.
  static Future<void> loeschen(int id) => ApiClient.dio.delete('$_pfad/$id');
}

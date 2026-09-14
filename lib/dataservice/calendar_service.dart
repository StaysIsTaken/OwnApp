import 'package:productivity/dataclasses/kalender.dart';
import 'package:productivity/dataclasses/kalender_freigabe.dart';
import 'package:productivity/dataservice/api_client.dart';

/// Kalender: auflisten, anlegen, ändern, löschen, abholen.
class CalendarService {
  CalendarService._();

  static const String _pfad = '/calendars';

  /// Die eigenen und die mir freigegebenen Kalender.
  ///
  /// Fremde Kalender kommen nur hierher, wenn ihr Besitzer sie freigegeben
  /// hat. [alle] zeigt den ganzen Haushalt und ist Admin und Küchen-Tablet
  /// vorbehalten — bewusst ein ausdrücklicher Schalter: das Tablet setzt
  /// ihn, dasselbe Konto am Telefon nicht.
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

  // ── Freigabe ──────────────────────────────────────────────────────────
  // Nur der Besitzer darf das; der Server prüft es und antwortet sonst mit
  // 403.

  static Future<List<KalenderFreigabe>> freigaben(int kalenderId) async {
    final r = await ApiClient.dio.get('$_pfad/$kalenderId/freigaben');
    return (r.data as List<dynamic>)
        .map((e) => KalenderFreigabe.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Gibt den Kalender für eine Person frei — oder ändert ihren Filter.
  ///
  /// Zweimal dieselbe Person freigeben ist kein Fehler, sondern eine
  /// Änderung. Deshalb `PUT`: die Oberfläche muss nicht erst nachsehen, ob
  /// es die Freigabe schon gibt.
  static Future<KalenderFreigabe> freigeben(
    int kalenderId, {
    required String userId,
    List<int> typIds = const [],
    String? stichwort,
  }) async {
    final r = await ApiClient.dio.put('$_pfad/$kalenderId/freigaben', data: {
      'user_id': userId,
      'filter_type_ids': typIds,
      'filter_keyword': (stichwort?.trim().isEmpty ?? true) ? null : stichwort!.trim(),
    });
    return KalenderFreigabe.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<void> freigabeEntziehen(int kalenderId, String userId) =>
      ApiClient.dio.delete('$_pfad/$kalenderId/freigaben/$userId');
}

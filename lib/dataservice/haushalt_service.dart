import 'package:dio/dio.dart';
import 'package:productivity/dataclasses/haushalt.dart';
import 'package:productivity/dataservice/api_client.dart';

/// Der Haushalt: anlegen, einladen, beitreten, verlassen, auflösen.
///
/// **In keinem Haushalt zu sein ist der Normalfall**, kein Fehler. Der
/// Server antwortet darauf mit 204, und [meiner] gibt `null` zurück —
/// nicht eine Ausnahme, die jede aufrufende Stelle abfangen müsste.
class HaushaltService {
  HaushaltService._();

  static const String _pfad = '/haushalt';

  /// Der eigene Haushalt — oder null.
  static Future<Haushalt?> meiner() async {
    final r = await ApiClient.dio.get(_pfad);
    // 204: kein Haushalt. Dio gibt dann einen leeren Rumpf, und `data`
    // ist je nach Plattform null oder ein leerer String.
    if (r.statusCode == 204 || r.data == null || r.data == '') return null;
    return Haushalt.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<Haushalt> anlegen(String name,
      {String color = '#0EA5E9'}) async {
    final r = await ApiClient.dio
        .post(_pfad, data: {'name': name, 'color': color});
    return Haushalt.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<Haushalt> aendern({String? name, String? color}) async {
    final r = await ApiClient.dio.put(_pfad, data: {
      'name': ?name,
      'color': ?color,
    });
    return Haushalt.fromJson(r.data as Map<String, dynamic>);
  }

  /// Löst den Haushalt auf. Die Daten bleiben und fallen an den Besitzer.
  static Future<void> aufloesen() async {
    await ApiClient.dio.delete(_pfad);
  }

  // ── Mitglieder ─────────────────────────────────────────────────────────

  /// Was die anderen von meinen Finanzen sehen — entscheide ich.
  static Future<Mitglied> finanzsicht(Finanzsicht stufe) async {
    final r = await ApiClient.dio.put(
      '$_pfad/finanz-sicht',
      data: {'finanz_sicht': stufe.schluessel},
    );
    return Mitglied.fromJson(r.data as Map<String, dynamic>);
  }

  /// Ich gehe. Bin ich der Letzte, löst sich der Haushalt auf.
  static Future<void> austreten() async {
    await ApiClient.dio.delete('$_pfad/mitglieder/me');
  }

  static Future<void> entfernen(String userId) async {
    await ApiClient.dio.delete('$_pfad/mitglieder/$userId');
  }

  /// Jemand anderes führt den Haushalt ab jetzt — der Weg hinaus für den
  /// Besitzer, denn gehen kann er erst danach.
  static Future<Haushalt> uebergeben(String userId) async {
    final r = await ApiClient.dio.post('$_pfad/besitz/$userId');
    return Haushalt.fromJson(r.data as Map<String, dynamic>);
  }

  // ── Einladungen ────────────────────────────────────────────────────────

  /// Offene Einladungen **an mich**.
  static Future<List<Einladung>> meineEinladungen() async {
    final r = await ApiClient.dio.get('$_pfad/einladungen');
    return (r.data as List<dynamic>)
        .map((e) => Einladung.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Offene Einladungen, die der Haushalt verschickt hat.
  static Future<List<Einladung>> gesendeteEinladungen() async {
    final r = await ApiClient.dio.get('$_pfad/einladungen/gesendet');
    return (r.data as List<dynamic>)
        .map((e) => Einladung.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Einladung> einladen(String userId) async {
    final r = await ApiClient.dio
        .post('$_pfad/einladungen', data: {'user_id': userId});
    return Einladung.fromJson(r.data as Map<String, dynamic>);
  }

  /// Annehmen — mit der Stufe aus dem Pop-up.
  ///
  /// Die Stufe steht hier ohne Vorgabe im Aufruf und nicht als
  /// Voreinstellung im Dienst: das Pop-up soll erschienen sein, bevor
  /// jemand Mitglied wird.
  static Future<Haushalt> annehmen(int einladungId, Finanzsicht stufe) async {
    final r = await ApiClient.dio.post(
      '$_pfad/einladungen/$einladungId/annehmen',
      data: {'finanz_sicht': stufe.schluessel},
    );
    return Haushalt.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<void> ablehnen(int einladungId) async {
    await ApiClient.dio.post('$_pfad/einladungen/$einladungId/ablehnen');
  }

  static Future<void> zurueckziehen(int einladungId) async {
    await ApiClient.dio.delete('$_pfad/einladungen/$einladungId');
  }

  /// Ob dieses Backend Haushalte überhaupt kennt.
  ///
  /// Ein älterer Server antwortet auf `/haushalt` mit 404. Das ist kein
  /// Fehler, den man dem Nutzer zeigt — die App verhält sich dann einfach
  /// wie vorher.
  static bool istUnbekannt(Object fehler) =>
      fehler is DioException && fehler.response?.statusCode == 404;
}

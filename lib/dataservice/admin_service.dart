import 'package:productivity/dataclasses/admin.dart';
import 'package:productivity/dataservice/api_client.dart';

/// Zugriff auf den Adminbereich des Backends.
///
/// Alle Aufrufe hier verlangen serverseitig `admin:roles` bzw. `admin:users`.
/// Die App blendet die Seite zwar aus, wenn das Recht fehlt — das ist aber
/// nur Höflichkeit; verlassen muss man sich auf die Prüfung im Backend.
class AdminService {
  AdminService._();

  static const String _path = '/admin';

  static Future<List<Recht>> rechteKatalog() async {
    final r = await ApiClient.dio.get('$_path/permissions');
    return (r.data as List<dynamic>)
        .map((e) => Recht.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Rolle>> rollen() async {
    final r = await ApiClient.dio.get('$_path/roles');
    return (r.data as List<dynamic>)
        .map((e) => Rolle.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Rolle> rolleAnlegen({
    required String key,
    required String name,
    String? beschreibung,
    required List<String> rechte,
  }) async {
    final r = await ApiClient.dio.post('$_path/roles', data: {
      'key': key,
      'name': name,
      'description': beschreibung,
      'permissions': rechte,
    });
    return Rolle.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<Rolle> rolleAendern(
    String roleId, {
    String? name,
    String? beschreibung,
    List<String>? rechte,
  }) async {
    final daten = <String, dynamic>{};
    if (name != null) daten['name'] = name;
    if (beschreibung != null) daten['description'] = beschreibung;
    if (rechte != null) daten['permissions'] = rechte;
    final r = await ApiClient.dio.put('$_path/roles/$roleId', data: daten);
    return Rolle.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<void> rolleLoeschen(String roleId) =>
      ApiClient.dio.delete('$_path/roles/$roleId');

  /// `roleId: null` heißt: neue Nutzer bekommen keine Rolle und müssen erst
  /// freigeschaltet werden.
  static Future<void> standardrolleSetzen(String? roleId) =>
      ApiClient.dio.put('$_path/default-role', data: {'role_id': roleId});

  static Future<List<AdminBenutzer>> benutzer() async {
    final r = await ApiClient.dio.get('$_path/users');
    return (r.data as List<dynamic>)
        .map((e) => AdminBenutzer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<AdminBenutzer> benutzerAnlegen({
    required String username,
    required String vorname,
    required String nachname,
    required String passwort,
    List<String>? roleIds,
  }) async {
    final daten = <String, dynamic>{
      'username': username,
      'first_name': vorname,
      'last_name': nachname,
      'password': passwort,
    };
    // Weglassen heisst "Standardrolle", `[]` heisst ausdruecklich keine.
    if (roleIds != null) daten['role_ids'] = roleIds;
    final r = await ApiClient.dio.post('$_path/users', data: daten);
    return AdminBenutzer.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<void> passwortSetzen(String userId, String passwort) =>
      ApiClient.dio
          .put('$_path/users/$userId/password', data: {'password': passwort});

  /// Deaktiviert heißt: kommt nicht mehr herein, die Daten bleiben.
  static Future<AdminBenutzer> aktivSetzen(String userId, bool aktiv) async {
    final r = await ApiClient.dio
        .put('$_path/users/$userId/active', data: {'active': aktiv});
    return AdminBenutzer.fromJson(r.data as Map<String, dynamic>);
  }

  /// Ohne `mitDaten` verweigert der Server, sobald noch etwas da ist, und
  /// sagt in `detail.data`, was es ist.
  static Future<void> benutzerLoeschen(String userId,
          {bool mitDaten = false}) =>
      ApiClient.dio.delete('$_path/users/$userId',
          queryParameters: {'mit_daten': mitDaten});

  static Future<AdminBenutzer> rollenSetzen(
      String userId, List<String> roleIds) async {
    final r = await ApiClient.dio
        .put('$_path/users/$userId/roles', data: {'role_ids': roleIds});
    return AdminBenutzer.fromJson(r.data as Map<String, dynamic>);
  }
}

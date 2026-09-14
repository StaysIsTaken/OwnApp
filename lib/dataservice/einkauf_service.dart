import 'package:productivity/dataclasses/einkauf.dart';
import 'package:productivity/dataservice/api_client.dart';

/// Einkaufslisten, Positionen und das Preisgedächtnis.
///
/// Nachfolger von `ShoppingListService` — und seit der Umstellung von
/// Essensplan und Vorratsübernahme dessen vollständiger Ersatz.
class EinkaufService {
  EinkaufService._();

  static const String _pfad = '/einkauf';

  // ── Listen ─────────────────────────────────────────────────────────────

  /// Eigene Listen und die, auf denen man steht.
  ///
  /// [alle] holt die der übrigen Personen dazu und verlangt
  /// `shopping:read_all` — das Küchen-Tablet setzt es, das Telefon nicht.
  static Future<List<Einkaufsliste>> listen({bool alle = false}) async {
    final r = await ApiClient.dio.get(
      _pfad,
      queryParameters: alle ? {'alle': true} : null,
    );
    return (r.data as List<dynamic>)
        .map((e) => Einkaufsliste.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Einkaufsliste> listeAnlegen(String name,
      {String color = '#3B82F6'}) async {
    final r = await ApiClient.dio
        .post(_pfad, data: {'name': name, 'color': color});
    return Einkaufsliste.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<Einkaufsliste> listeAendern(int id,
      {String? name, String? color}) async {
    final r = await ApiClient.dio.put('$_pfad/$id', data: {
      'name': ?name,
      'color': ?color,
    });
    return Einkaufsliste.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<void> listeLoeschen(int id) =>
      ApiClient.dio.delete('$_pfad/$id');

  static Future<void> mitgliedHinzufuegen(int listId, String userId) =>
      ApiClient.dio.post('$_pfad/$listId/mitglieder/$userId');

  static Future<void> mitgliedEntfernen(int listId, String userId) =>
      ApiClient.dio.delete('$_pfad/$listId/mitglieder/$userId');

  // ── Positionen ─────────────────────────────────────────────────────────

  static Future<List<Einkaufsposition>> positionen(int listId,
      {bool mitErledigten = true}) async {
    final r = await ApiClient.dio.get(
      '$_pfad/$listId/positionen',
      queryParameters: mitErledigten ? null : {'mit_erledigten': false},
    );
    return (r.data as List<dynamic>)
        .map((e) => Einkaufsposition.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Einkaufsposition> positionAnlegen(
    int listId, {
    required String name,
    double? menge,
    String? ingredientId,
    String? unitId,
    String? notiz,
  }) async {
    final r = await ApiClient.dio.post('$_pfad/$listId/positionen', data: {
      'name': name,
      'amount': ?menge,
      'ingredient_id': ?ingredientId,
      'unit_id': ?unitId,
      'note': ?notiz,
    });
    return Einkaufsposition.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<Einkaufsposition> positionAendern(
    int positionId, {
    String? name,
    double? menge,
    String? notiz,
    bool? erledigt,
  }) async {
    final r = await ApiClient.dio.put('$_pfad/positionen/$positionId', data: {
      'name': ?name,
      'amount': ?menge,
      'note': ?notiz,
      'is_done': ?erledigt,
    });
    return Einkaufsposition.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<void> positionLoeschen(int positionId) =>
      ApiClient.dio.delete('$_pfad/positionen/$positionId');

  /// Wirft alles Abgehakte weg. Gibt zurück, wie viel es war.
  static Future<int> aufraeumen(int listId) async {
    final r = await ApiClient.dio.post('$_pfad/$listId/aufraeumen');
    return ((r.data as Map)['entfernt'] as num?)?.toInt() ?? 0;
  }

  // ── Die Brücke hinaus: Einkauf → Vorrat ───────────────────────────────

  /// Bucht die abgehakten Positionen in den Vorrat.
  ///
  /// [entfernen] räumt sie danach von der Liste — das ist der übliche Wunsch
  /// nach dem Einkauf. Gerechnet wird auf dem Server, weil dort der Vorrat
  /// liegt und Einheiten umgerechnet werden müssen.
  static Future<VorratErgebnis> inDenVorrat(int listId,
      {bool entfernen = true}) async {
    final r = await ApiClient.dio.post(
      '$_pfad/$listId/in-den-vorrat',
      queryParameters: {'entfernen': entfernen},
    );
    return VorratErgebnis.fromJson(r.data as Map<String, dynamic>);
  }

  // ── Preisgedächtnis ────────────────────────────────────────────────────

  /// Was für diese Ware bekannt ist — günstigstes zuerst.
  ///
  /// Fällt still auf eine leere Liste zurück: der Preishinweis ist eine
  /// Zugabe beim Tippen, kein Grund, das Anlegen scheitern zu lassen.
  static Future<List<Warenpreis>> preise(String bezeichnung) async {
    try {
      final r = await ApiClient.dio
          .get('$_pfad/preise/${Uri.encodeComponent(bezeichnung)}');
      return (r.data as List<dynamic>)
          .map((e) => Warenpreis.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Was in diesem Laden was kostet — die Gegenrichtung zu [preise].
  ///
  /// Dort fragt man „wo ist die Butter billig", hier „was weiss ich ueber
  /// diesen Laden". Faellt wie [preise] still auf eine leere Liste zurueck.
  static Future<List<Warenpreis>> preiseImLaden(String shopId) async {
    try {
      final r = await ApiClient.dio.get('$_pfad/laeden/$shopId/preise');
      return (r.data as List<dynamic>)
          .map((e) => Warenpreis.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<Warenpreis> preisMerken({
    required String bezeichnung,
    required String shopId,
    required double preis,
    double? menge,
    String? unitId,
    String? ingredientId,
  }) async {
    final r = await ApiClient.dio.post('$_pfad/preise', data: {
      'bezeichnung': bezeichnung,
      'shop_id': shopId,
      'price': preis,
      'amount': ?menge,
      'unit_id': ?unitId,
      'ingredient_id': ?ingredientId,
    });
    return Warenpreis.fromJson(r.data as Map<String, dynamic>);
  }
}

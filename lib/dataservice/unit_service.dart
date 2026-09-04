import 'package:productivity/dataclasses/unit.dart';
import 'package:productivity/dataservice/api_client.dart';

// ─────────────────────────────────────────────
//  UnitService – API-backed
// ─────────────────────────────────────────────
class UnitService {
  UnitService._();

  static const String _path = '/units';

  static Future<List<Unit>> loadAll() async {
    final response = await ApiClient.dio.get(_path);
    return (response.data['items'] as List<dynamic>)
        .map((e) => Unit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Unit> getById(String id) async {
    final response = await ApiClient.dio.get('$_path/$id');
    return Unit.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Unit> create(Unit unit) async {
    final response = await ApiClient.dio.post(_path, data: unit.toJson());
    return Unit.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Unit> update(Unit unit) async {
    final response = await ApiClient.dio.put(
      '$_path/${unit.id}',
      data: unit.toJson(),
    );
    return Unit.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> delete(String id) async {
    await ApiClient.dio.delete('$_path/$id');
  }

  /// Inserts or replaces – convenience wrapper kept for API compatibility.
  /// Legt neu an oder aktualisiert – entschieden an der id, nicht am Fehlerfall.
  ///
  /// Vorher lief hier immer erst ein `update`, und JEDER Fehler führte zum
  /// `create`. Beim Anlegen kostete das einen überflüssigen Request, und beim
  /// Bearbeiten legte ein Netzwerkaussetzer oder ein 500 still ein Duplikat an,
  /// statt den Fehler zu melden.
  static Future<Unit> upsert(Unit unit) async {
    return unit.id.isEmpty ? create(unit) : update(unit);
  }
}

import 'package:productivity/dataclasses/pantry_item.dart';
import 'package:productivity/dataclasses/pantry_extras.dart';
import 'package:productivity/dataservice/api_client.dart';
import 'package:productivity/dataservice/haushalt_sicht.dart';

class PantryService {
  PantryService._();

  static const String _pantryPath = '/pantry';
  static const String _locationPath = '/storage-locations';

  // --- Storage Locations ---
  static Future<List<StorageLocation>> loadLocations() async {
    final response = await ApiClient.dio.get(_locationPath);
    // API returns {"total": X, "items": [...]}
    final list = response.data['items'] as List<dynamic>;
    return list.map((e) => StorageLocation.fromJson(e)).toList();
  }

  static Future<StorageLocation> upsertLocation(StorageLocation loc) async {
    if (loc.id.isEmpty) {
      final response = await ApiClient.dio.post(
        _locationPath,
        data: loc.toJson(),
      );
      return StorageLocation.fromJson(response.data);
    } else {
      final response = await ApiClient.dio.put(
        '$_locationPath/${loc.id}',
        data: loc.toJson(),
      );
      return StorageLocation.fromJson(response.data);
    }
  }

  /// „Das steht ab jetzt in unserem Schrank." Oder wieder in meinem.
  static Future<PantryItem> zuordnen(String id, bool unseres) async {
    final r = await ApiClient.dio
        .put('$_pantryPath/$id/haushalt', data: {'unseres': unseres});
    return PantryItem.fromJson(r.data);
  }

  static Future<void> deleteLocation(String id) async {
    await ApiClient.dio.delete('$_locationPath/$id');
  }

  // --- Pantry Items ---
  /// [bereich] ist die Umschaltung „Alles / Meins / Unseres".
  static Future<List<PantryItem>> loadAll(
      {Bereich bereich = Bereich.alles}) async {
    final response = await ApiClient.dio.get(
      _pantryPath,
      queryParameters: bereich.abfrage.isEmpty ? null : bereich.abfrage,
    );
    // API returns {"total": X, "items": [...]}
    final list = response.data['items'] as List<dynamic>;
    return list.map((e) => PantryItem.fromJson(e)).toList();
  }

  /// Legt an oder ändert. [unseres] gilt nur beim Anlegen — wo etwas
  /// später hingehört, entscheidet die Verschiebe-Aktion, nicht ein
  /// beiläufiges Speichern.
  static Future<PantryItem> upsert(PantryItem item,
      {bool unseres = false}) async {
    if (item.id.isEmpty) {
      final response = await ApiClient.dio.post(
        _pantryPath,
        data: {...item.toJson(), 'unseres': unseres},
      );
      return PantryItem.fromJson(response.data);
    } else {
      final response = await ApiClient.dio.put(
        '$_pantryPath/${item.id}',
        data: item.toJson(),
      );
      return PantryItem.fromJson(response.data);
    }
  }

  static Future<void> delete(String id) async {
    await ApiClient.dio.delete('$_pantryPath/$id');
  }

  /// Special update for amount/quantity changes
  static Future<void> updateQuantity(String id, double delta) async {
    // Check if API has a dedicated delta endpoint, otherwise we'd need to get then put
    // Based on pantry.py, there is no delta endpoint, so we should just use put via upsert
  }
}

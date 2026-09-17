import 'package:productivity/dataclasses/einstellungen.dart';
import 'package:productivity/dataservice/api_client.dart';

/// Die eigenen Einstellungen — lesen und ändern.
///
/// Immer die eigenen: der Server nimmt keine fremde Kennung entgegen, der
/// Nutzer kommt aus dem Token. Deshalb braucht der Endpunkt auch kein
/// Recht, und es gibt hier nichts zu übergeben außer den Werten selbst.
class EinstellungsService {
  EinstellungsService._();

  static const String _pfad = '/einstellungen';

  static Future<Einstellungen> lesen() async {
    final r = await ApiClient.dio.get(_pfad);
    return Einstellungen.fromJson(r.data as Map<String, dynamic>);
  }

  /// Ändert, was mitkommt. Was fehlt, bleibt — der Server fasst nur an,
  /// was im Rumpf steht.
  ///
  /// Deshalb nimmt diese Stelle eine fertige Karte statt benannter
  /// Parameter: „nicht mitgeschickt" und „auf null gesetzt" sind
  /// verschiedene Dinge, und mit `String?` ließen sie sich nicht
  /// auseinanderhalten.
  static Future<Einstellungen> aendern(Map<String, dynamic> daten) async {
    final r = await ApiClient.dio.put(_pfad, data: daten);
    return Einstellungen.fromJson(r.data as Map<String, dynamic>);
  }
}

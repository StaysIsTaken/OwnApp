import 'package:productivity/dataclasses/mcp_zugang.dart';
import 'package:productivity/dataservice/api_client.dart';

/// Der eigene MCP-Zugang: Stand holen, Schalter umlegen, Schlüssel neu.
///
/// Immer der eigene — der Server nimmt keine fremde Kennung entgegen.
class McpService {
  McpService._();

  static const String _pfad = '/einstellungen/mcp';

  static Future<McpZugang> lesen() async {
    final r = await ApiClient.dio.get(_pfad);
    return McpZugang.fromJson(r.data as Map<String, dynamic>);
  }

  /// Legt **einen** Schalter um und bekommt den ganzen Stand zurück.
  ///
  /// Einer und nicht der ganze Baum: ein Client, der alle Felder schicken
  /// müsste, schaltete beim Speichern still aus, was er nicht kennt. Bei
  /// Einstellungen, an denen hängt, ob Daten das Haus verlassen, ist das
  /// die falsche Richtung von Vergesslichkeit.
  static Future<McpZugang> schalte(String feld, bool an) async {
    final r = await ApiClient.dio.put(_pfad, data: {'feld': feld, 'an': an});
    return McpZugang.fromJson(r.data as Map<String, dynamic>);
  }

  /// Erzeugt einen neuen Schlüssel — der alte gilt ab sofort nicht mehr.
  ///
  /// Die Antwort ist die einzige Gelegenheit, ihn zu sehen.
  static Future<McpSchluessel> schluesselNeu() async {
    final r = await ApiClient.dio.post('$_pfad/schluessel');
    return McpSchluessel.fromJson(r.data as Map<String, dynamic>);
  }
}

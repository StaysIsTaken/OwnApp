import 'package:dio/dio.dart';
import 'package:productivity/dataservice/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wo die API steht — einstellbar, statt beim Bauen festgeklopft.
///
/// Bisher kam die Adresse ausschließlich aus `--dart-define=API_URL`. Wer
/// die App auf einem eigenen Server betreibt, hätte damit ein eigenes Bild
/// bauen müssen. Jetzt gilt:
///
///   1. was der Nutzer eingestellt hat
///   2. sonst `--dart-define=API_URL` aus dem Bauvorgang
///   3. sonst die eingebaute Vorgabe
///
/// Die Reihenfolge ist wichtig: ein fertiges Bild bringt eine brauchbare
/// Vorgabe mit, und wer eine andere braucht, ändert sie in der App.
class ServerConfig {
  ServerConfig._();

  static const String _schluessel = 'api_base_url';

  /// Was beim Bauen mitgegeben wurde. Leer, wenn nichts gesetzt war.
  static const String _ausDemBauvorgang = String.fromEnvironment('API_URL');

  /// Die eingebaute Vorgabe – der Server, für den die App ursprünglich
  /// gebaut wurde.
  static const String eingebauteVorgabe = 'https://api.home-anft.de/api';

  static String get vorgabe =>
      _ausDemBauvorgang.isEmpty ? eingebauteVorgabe : _ausDemBauvorgang;

  /// Die API auf derselben Seite, von der die App geladen wurde – oder
  /// `null`, wenn das keinen Sinn ergibt (also überall außer im Browser).
  ///
  /// Wer die App und die API hinter derselben Domain betreibt, hat damit
  /// nichts zu tippen.
  static String? get dieseSeite {
    final basis = Uri.base;
    if (basis.scheme != 'http' && basis.scheme != 'https') return null;
    if (basis.host.isEmpty) return null;
    return '${basis.origin}/api';
  }

  /// Beim Start aufrufen, bevor irgendein Dienst etwas anfragt.
  static Future<String> anwenden() async {
    final gespeichert = await geladene();
    ApiClient.setBaseUrl(gespeichert ?? vorgabe);
    return ApiClient.baseUrl;
  }

  static Future<String?> geladene() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wert = prefs.getString(_schluessel);
      return (wert == null || wert.isEmpty) ? null : wert;
    } catch (_) {
      // Kein Speicher verfügbar (privates Fenster, frisch installiert):
      // dann gilt eben die Vorgabe.
      return null;
    }
  }

  static Future<void> speichern(String url) async {
    ApiClient.setBaseUrl(url);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_schluessel, url);
    } catch (_) {
      // Nicht speicherbar: die Adresse gilt wenigstens bis zum Neustart.
    }
  }

  static Future<void> zuruecksetzen() async {
    ApiClient.setBaseUrl(vorgabe);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_schluessel);
    } catch (_) {}
  }

  /// Macht aus dem, was jemand eintippt, eine brauchbare Adresse.
  ///
  /// Absichtlich großzügig: „meinserver.de" ist das, was Leute eingeben,
  /// und daran soll es nicht scheitern. Was daraus wird, zeigt die
  /// Oberfläche an, bevor gespeichert wird — geraten wird nichts im
  /// Verborgenen.
  static String normalisieren(String eingabe) {
    var text = eingabe.trim();
    if (text.isEmpty) return '';

    // Ohne Schema wird https angenommen. http nur, wenn es dasteht — sonst
    // würde eine Adresse unbemerkt unverschlüsselt laufen.
    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      text = 'https://$text';
    }
    while (text.endsWith('/')) {
      text = text.substring(0, text.length - 1);
    }

    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) return text;

    // Ohne Pfad hängen wir /api an — dort liegen die Endpunkte. Hat jemand
    // schon einen Pfad angegeben, bleibt der stehen: hinter einem
    // Reverse-Proxy kann die API auch woanders hängen.
    if (uri.path.isEmpty) {
      text = '$text/api';
    }
    return text;
  }

  /// Antwortet dort wirklich diese API?
  ///
  /// `/auth/registration-status` ist der richtige Prüfstein: er braucht
  /// keine Anmeldung, ist billig, und es gibt ihn nur hier. Ein beliebiger
  /// Webserver würde 404 liefern statt eines JSON mit `open`.
  static Future<ServerPruefung> pruefen(String url) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
    ));
    try {
      final antwort = await dio.get('$url/auth/registration-status');
      final daten = antwort.data;
      if (daten is Map && daten.containsKey('open')) {
        return ServerPruefung(
          erreichbar: true,
          registrierungOffen: daten['open'] == true,
        );
      }
      return const ServerPruefung(
        erreichbar: false,
        meldung: 'Dort antwortet etwas, aber es ist nicht diese API.',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const ServerPruefung(
          erreichbar: false,
          meldung: 'Erreichbar, aber unter dieser Adresse liegt keine API. '
              'Fehlt vielleicht /api am Ende?',
        );
      }
      if (e.response != null) {
        return ServerPruefung(
          erreichbar: false,
          meldung: 'Der Server antwortet mit ${e.response!.statusCode}.',
        );
      }
      return const ServerPruefung(
        erreichbar: false,
        meldung: 'Keine Verbindung. Adresse richtig? Server erreichbar?',
      );
    } catch (_) {
      return const ServerPruefung(
        erreichbar: false,
        meldung: 'Die Adresse konnte nicht geprüft werden.',
      );
    }
  }
}

class ServerPruefung {
  final bool erreichbar;
  final bool registrierungOffen;
  final String? meldung;

  const ServerPruefung({
    required this.erreichbar,
    this.registrierungOffen = false,
    this.meldung,
  });
}

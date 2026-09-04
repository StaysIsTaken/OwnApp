import 'package:dio/dio.dart';

/// Fehler vom Server in einen Satz übersetzen, den man lesen kann.
///
/// Vor allem 403: das Backend schickt zu jedem fehlenden Recht eine
/// verständliche Begründung mit — die soll auch ankommen und nicht als
/// roher `DioException` durchfallen.
class ApiFehler {
  ApiFehler._();

  /// Angemeldet, aber nicht berechtigt. (401 wäre "nicht angemeldet" und
  /// führt an anderer Stelle zum Abmelden.)
  static bool istVerboten(Object fehler) =>
      fehler is DioException && fehler.response?.statusCode == 403;

  static bool istNichtGefunden(Object fehler) =>
      fehler is DioException && fehler.response?.statusCode == 404;

  /// Kein Netz, Zeitüberschreitung, Server weg — alles, was nichts mit
  /// Berechtigungen zu tun hat.
  static bool istNetzproblem(Object fehler) {
    if (fehler is! DioException) return false;
    return fehler.response == null;
  }

  /// Der Satz, den der Server mitgeschickt hat — oder ein passender
  /// Ersatz.
  static String text(Object fehler) {
    if (fehler is! DioException) return 'Das hat nicht geklappt.';

    final detail = fehler.response?.data;
    if (detail is Map && detail['detail'] is String) {
      return detail['detail'] as String;
    }

    switch (fehler.response?.statusCode) {
      case 403:
        return 'Dafür fehlt dir die Berechtigung.';
      case 404:
        return 'Das gibt es nicht (mehr).';
      case 500:
        return 'Auf dem Server ist etwas schiefgegangen.';
    }
    if (istNetzproblem(fehler)) {
      return 'Der Server ist gerade nicht erreichbar.';
    }
    return 'Das hat nicht geklappt.';
  }
}

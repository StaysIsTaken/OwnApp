import 'package:productivity/dataclasses/einstellungen.dart';

/// Die Übergabe vom Gerät ans Konto — als reine Rechnung.
///
/// Die Einstellungen lagen bisher in den SharedPreferences. Beim ersten
/// Anmelden nach der Umstellung muss entschieden werden, was davon nach
/// oben wandert und was der Server schon besser weiß. Diese Entscheidung
/// steht hier und nicht im Provider, weil der beim Aufbau lädt und sich
/// damit nicht prüfen lässt — derselbe Kunstgriff wie bei
/// `finanz_rechnung.dart` und `haushalt_sicht.dart`.
class Einstellungsabgleich {
  Einstellungsabgleich._();

  /// Was beim ersten Abgleich dieses Geräts hochgeschickt werden muss.
  ///
  /// Leere Karte heißt: nichts zu tun, der Server gilt.
  ///
  /// Die Regel ist bewusst einfach: **was der Server nicht weiß, lernt er
  /// vom Gerät; was er weiß, gewinnt.** Ein Wert, den dort schon jemand
  /// gesetzt hat, wird nie überschrieben — sonst würde ein zweites Gerät
  /// beim ersten Anmelden die Einstellungen des ersten kaputtmachen.
  ///
  /// [schonUebertragen] merkt sich das Gerät. Ohne dieses Merken liefe
  /// der Abgleich bei jeder Anmeldung erneut und schöbe alte
  /// Gerätestände wieder hoch, die man auf einem anderen Gerät längst
  /// geändert hat.
  static Map<String, dynamic> uebergabe({
    required bool schonUebertragen,
    required Einstellungen vomServer,
    required bool geraetUse24h,
    required String geraetWetterOrt,
    required String geraetKiModell,
    required double geraetKiTemperatur,
    required int geraetKiMaxTokens,
  }) {
    if (schonUebertragen) return const {};

    final daten = <String, dynamic>{};

    // `use_24h` ist nie leer — der Server hat dort immer true oder false.
    // "Weiß er es nicht" gibt es hier also nicht, und deshalb zählt beim
    // allerersten Mal das Gerät: dort hat es jemand eingestellt, auf dem
    // Server stand nur die Vorgabe.
    if (vomServer.use24h != geraetUse24h) {
      daten['use_24h'] = geraetUse24h;
    }

    if ((vomServer.wetterOrt ?? '').isEmpty && geraetWetterOrt.isNotEmpty) {
      daten['weather_city'] = geraetWetterOrt;
    }

    // Die drei KI-Werte sind der eigentliche Anlass: es gab sie doppelt,
    // am Gerät und auf dem Server, und je nach Seite galt eine andere
    // Zahl. Ab jetzt gilt die vom Server — aber wenn dort nichts steht,
    // wäre das ein Rückschritt gegenüber dem, was der Nutzer eingestellt
    // hatte.
    if ((vomServer.kiModell ?? '').isEmpty && geraetKiModell.isNotEmpty) {
      daten['ai_model'] = geraetKiModell;
    }
    if (vomServer.kiTemperatur == null) {
      daten['ai_temperature'] = geraetKiTemperatur;
    }
    if (vomServer.kiMaxTokens == null) {
      daten['ai_max_tokens'] = geraetKiMaxTokens;
    }

    return daten;
  }
}

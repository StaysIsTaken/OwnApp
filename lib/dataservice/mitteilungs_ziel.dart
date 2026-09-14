import 'package:flutter/widgets.dart';

/// Wohin ein Tipp auf eine Mitteilung führt.
///
/// Die Mitteilung trägt seit jeher einen `payload` wie `planner:42` — nur
/// wertete ihn niemand aus. `_handleNotificationTap` war eine leere
/// Attrappe mit dem Kommentar „could be used for routing".
///
/// Das Auswerten liegt hier und nicht im [LocalNotificationManager], weil
/// zwei Wege hineinführen und sie sich sonst doppeln würden:
///
/// * **Die App lief schon** (Vorder- oder Hintergrund) — der Callback des
///   Plugins feuert.
/// * **Die App lief nicht.** Dann feuert gar nichts: sie startet erst durch
///   den Tipp, und der Grund steht in `getNotificationAppLaunchDetails()`.
///   Ohne diesen zweiten Weg funktioniert das Antippen nur, solange die App
///   ohnehin schon offen war — ein Fehler, der im Alltag erst auffällt und
///   dann schwer zuzuordnen ist.
class MitteilungsZiel {
  MitteilungsZiel._();

  /// Der Schlüssel zum Navigator der App.
  ///
  /// Nötig, weil der Callback des Plugins statisch ist und damit keinen
  /// `BuildContext` hat. `NotificationService.messengerKey` ist das
  /// Gegenstück für Schnipsel-Meldungen und existiert aus demselben Grund.
  static final GlobalKey<NavigatorState> navigator =
      GlobalKey<NavigatorState>();

  /// Ein Ziel, das beim Start anlag, bevor der Navigator bereit war.
  static String? _wartend;

  /// Merkt sich ein Ziel, bis jemand danach fragt.
  ///
  /// Beim Kaltstart steht der Grund fest, bevor das erste Bild gezeichnet
  /// ist — der Navigator existiert dann noch nicht.
  static void merken(String? payload) {
    if (payload != null && payload.isNotEmpty) _wartend = payload;
  }

  /// Holt ein gemerktes Ziel und vergisst es dabei.
  ///
  /// Das Vergessen ist wichtig: sonst spränge die App bei jedem Neuzeichnen
  /// wieder auf denselben Termin.
  static String? abholen() {
    final ziel = _wartend;
    _wartend = null;
    return ziel;
  }

  /// Wird gerufen, wenn ein Ziel eingetroffen ist, während die App läuft.
  ///
  /// Ohne diesen Haken läge das Ziel bis zum nächsten Neuzeichnen herum —
  /// und wer aus dem Hintergrund zurückkommt, zeichnet nicht unbedingt neu.
  static VoidCallback? beiNeuemZiel;

  static void anstossen() => beiNeuemZiel?.call();

  /// Zerlegt `planner:42` in die Nummer des Termins.
  ///
  /// Liefert null für alles andere — Vorrats- und Chat-Hinweise tragen
  /// eigene Präfixe und führen (noch) nirgendwohin.
  static int? terminAus(String? payload) {
    if (payload == null || !payload.startsWith('planner:')) return null;
    return int.tryParse(payload.substring('planner:'.length));
  }
}

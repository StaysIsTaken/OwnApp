/// Was für eine ganze Übersichtsseite gilt — nicht für eine einzelne Kachel.
///
/// Bisher war eine Seite nur eine Reihenfolge von Kacheln. Die Kalenderwahl
/// passt dort nicht hinein: sie gilt für alles auf der Seite, und genau
/// darauf beruht „Müllabfuhr nur auf dieser Seite". Der Kalender existiert
/// für alle; nur die Küchenseite blendet ihn ein.
class SeitenEinstellungen {
  /// Welche Kalender die Seite zeigt. `null` heißt **alle sichtbaren** —
  /// der Zustand vor jeder Auswahl und der Normalfall.
  ///
  /// Eine leere Liste ist etwas anderes als `null`: sie heißt „keiner",
  /// und das darf man einstellen können. Ohne den Unterschied könnte man
  /// eine Seite nie ganz leer schalten.
  final List<int>? kalender;

  /// Auch die Kalender der übrigen Personen holen (`planner:read_all`).
  /// Das Küchen-Tablet setzt es, dasselbe Konto am Telefon nicht.
  final bool alleKalender;

  const SeitenEinstellungen({this.kalender, this.alleKalender = false});

  static const leer = SeitenEinstellungen();

  bool get filtertKalender => kalender != null;

  bool zeigt(int? calendarId) {
    if (kalender == null) return true;
    if (calendarId == null) return false;
    return kalender!.contains(calendarId);
  }

  SeitenEinstellungen copyWith({
    List<int>? kalender,
    bool? kalenderLoeschen,
    bool? alleKalender,
  }) =>
      SeitenEinstellungen(
        kalender: kalenderLoeschen == true ? null : (kalender ?? this.kalender),
        alleKalender: alleKalender ?? this.alleKalender,
      );

  Map<String, dynamic> toJson() => {
        if (kalender != null) 'kalender': kalender,
        'alleKalender': alleKalender,
      };

  /// Aus dem, was das Backend verwahrt hat. Unbekanntes und Kaputtes wird
  /// übergangen statt geworfen: eine Einstellung aus einer neueren Version
  /// darf die Seite nicht zerlegen.
  factory SeitenEinstellungen.fromJson(Map<String, dynamic>? j) {
    if (j == null) return leer;
    List<int>? ids;
    final roh = j['kalender'];
    if (roh is List) {
      ids = [
        for (final e in roh)
          if (e is num) e.toInt() else if (int.tryParse('$e') != null) int.parse('$e'),
      ];
    }
    return SeitenEinstellungen(
      kalender: ids,
      alleKalender: j['alleKalender'] == true,
    );
  }
}

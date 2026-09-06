import 'package:productivity/tabs/dashboard/custom/tile_spec.dart';
import 'package:productivity/tabs/dashboard/custom/tile_views.dart';

/// Bricht die Kacheln in Reihen um.
///
/// Jede Kachel bringt ihre Breite in Spalten mit. Passt die nächste nicht
/// mehr in die laufende Reihe, beginnt eine neue — wie Wörter in einem
/// Absatz. Dadurch lässt sich nebeneinander stellen, was nebeneinander
/// gehört: eine schmale Einkaufsliste, daneben eine zweite, und wenn
/// rechts noch Platz ist, etwas Breiteres.
///
/// Die Reihenfolge bleibt, wie der Nutzer sie gezogen hat. Umsortieren, um
/// Lücken zu füllen, wäre klüger und zugleich unbrauchbar: die Kacheln
/// sprängen bei jeder Änderung anderswohin.
///
/// Eigene Funktion, weil die Küchenseite selbst nicht prüfbar ist — sie
/// lädt beim Aufbau vom Server. Diese Rechnung ist es.
/// Wie breit diese Kachel tatsächlich ist.
///
/// „Automatisch" heißt: ein Raster nimmt die ganze Reihe, alles andere
/// eine Spalte. Die Entscheidung hängt an der Darstellung — wer eine neue
/// Rasterdarstellung ergänzt, bekommt sie geschenkt, und alte Kacheln ohne
/// gespeicherte Größe sehen aus wie bisher.
int breiteVon(CustomTile k, int spalten) {
  if (!k.breiteAutomatisch) return k.breite.clamp(1, spalten);
  return TileViews.byKey(k.view)?.fuelltFlaeche == true ? spalten : 1;
}

/// Wie hoch, in Stufen. „Automatisch" heißt für ein Raster: volle Seite.
int hoeheVon(CustomTile k) {
  if (!k.hoeheAutomatisch) return k.hoehe.clamp(1, CustomTile.maxHoehe);
  return TileViews.byKey(k.view)?.fuelltFlaeche == true
      ? CustomTile.maxHoehe
      : 2;
}

List<List<CustomTile>> inReihen(List<CustomTile> kacheln, int spalten) {
  if (spalten < 1) return [for (final k in kacheln) [k]];

  final reihen = <List<CustomTile>>[];
  var laufende = <CustomTile>[];
  var belegt = 0;

  for (final k in kacheln) {
    // Breiter als das Raster gibt es nicht: sonst entstuende eine Reihe,
    // die ueber den Rand hinausragt.
    final breite = breiteVon(k, spalten);
    if (belegt + breite > spalten && laufende.isNotEmpty) {
      reihen.add(laufende);
      laufende = <CustomTile>[];
      belegt = 0;
    }
    laufende.add(k);
    belegt += breite;
  }
  if (laufende.isNotEmpty) reihen.add(laufende);
  return reihen;
}

/// Wie viele Spalten das Raster auf dieser Breite hat.
///
/// Auf einem schmalen Gerät wird alles untereinander gestapelt: vier
/// Spalten auf einem Telefon ergäben vier unlesbare Streifen.
int spaltenFuer(double breite) {
  if (breite >= 1500) return 4;
  if (breite >= 1100) return 3;
  if (breite >= 700) return 2;
  return 1;
}

/// Höhe einer Kachel aus ihrer Stufe.
///
/// Stufe 4 heißt „so hoch wie die Seite" — dafür braucht es die
/// verfügbare Höhe; die kleineren Stufen sind feste Maße, damit eine
/// Reihe aus zwei Kacheln nicht je nach Bildschirm anders aussieht.
double hoeheFuer(int stufe, double verfuegbar) {
  final ganz = (verfuegbar - 40).clamp(320.0, double.infinity);
  return switch (stufe.clamp(1, CustomTile.maxHoehe)) {
    1 => 220,
    2 => 340,
    3 => 520,
    _ => ganz,
  };
}

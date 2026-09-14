/// Gemeinsame Teile der beiden Wochenansichten.
///
/// **Warum nicht die ganze Ansicht?** Weil die beiden Raster nicht zwei
/// Fassungen desselben sind, sondern zwei verschiedene Rechnungen:
///
/// * Die Kachel leitet ihr Stundenfenster aus den Terminen ab (ein leerer
///   Vormittag verschenkt in einer Kachel die halbe Fläche) und passt die
///   Stundenhöhe an den vorhandenen Platz an. Sie legt ihre Termine
///   absolut in einen [Stack] über das ganze Raster.
/// * Der Planner zeigt immer 0 bis 24 Uhr bei fester Höhe, baut je Tag
///   eine Spalte und rechnet überlappende Termine in Nebenspalten. Dazu
///   Ziehen, Fallenlassen und Dialoge.
///
/// Ein Widget, das beides könnte, müsste Stundenfenster, Stundenhöhe, zwei
/// Platzierungsverfahren und die Bedienbarkeit als Schalter tragen — und
/// wäre schwerer zu lesen als die zwei Dateien zusammen. Was hier steht,
/// ist deshalb das, was **wirklich** dasselbe ist.
library;

import 'package:flutter/material.dart';

// ── Wo die Ansicht beginnt ───────────────────────────────────────────────

/// Welche Stunde beim Öffnen oben stehen soll.
///
/// Zeigt die Ansicht eine andere Woche, sagt „jetzt" nichts über sie aus —
/// dann lieber beim Vormittag anfangen als bei Mitternacht. Mitternacht
/// wäre die schlechtere Antwort: man sähe sechs leere Stunden und müsste
/// erst scrollen.
double zielStunde({required DateTime jetzt, required DateTime wochenStart}) {
  final ende = wochenStart.add(const Duration(days: 7));
  final inDieserWoche = !jetzt.isBefore(wochenStart) && jetzt.isBefore(ende);
  return inDieserWoche ? jetzt.hour + jetzt.minute / 60.0 : 8.0;
}

/// Der Versatz in Pixeln, mit dem eine Wochenansicht aufgehen soll.
///
/// Eine Stunde Vorlauf, damit auch der eben vergangene Termin noch zu sehen
/// ist; sonst klebt „jetzt" am oberen Rand. [abStunde] ist die oberste
/// gezeigte Stunde — im Planner 0, in der Kachel je nach Platz auch 8.
double startVersatz({
  required DateTime jetzt,
  required DateTime wochenStart,
  required double stundenHoehe,
  int abStunde = 0,
}) =>
    ((zielStunde(jetzt: jetzt, wochenStart: wochenStart) - abStunde - 1) *
            stundenHoehe)
        .clamp(0.0, double.infinity);

// ── Ganztägige Termine ───────────────────────────────────────────────────

/// Ein ganztägiger Eintrag, losgelöst davon, woher er kommt.
///
/// Die eine Ansicht kennt `PlannerEntry`, die andere `TileScheduleItem` —
/// der Streifen soll keine von beiden kennen müssen.
class Ganztagseintrag {
  final String titel;
  final DateTime von;
  final DateTime bis;
  final Color farbe;

  /// Null heißt: nicht antippbar. Die Küchenansicht führt bewusst nicht
  /// überall hin.
  final VoidCallback? beiTipp;

  const Ganztagseintrag({
    required this.titel,
    required this.von,
    required this.bis,
    required this.farbe,
    this.beiTipp,
  });

  /// Liegt dieser Termin auf dem genannten Tag?
  ///
  /// Nicht nur der Anfangstag: Schulferien fangen einmal an und dauern zwei
  /// Wochen. Wer nur den Beginn vergleicht, sieht sie am Montag und danach
  /// nie wieder.
  bool liegtAuf(DateTime tag) {
    final beginn = DateTime(tag.year, tag.month, tag.day);
    final ende = beginn.add(const Duration(days: 1));
    return von.isBefore(ende) && bis.isAfter(beginn);
  }
}

/// Der Streifen über dem Stundenraster.
///
/// So kommen Müllabfuhr, Feiertage und Schulferien herein — der ICS-Import
/// legt einen Termin ohne Uhrzeit als 00:00 bis 23:59 ab. Im Raster füllten
/// sie die komplette Tagesspalte und drängten alles Übrige an den Rand.
///
/// Er gehört **außerhalb** des Scrollbereichs: ein Feiertag soll auch dann
/// zu sehen sein, wenn man beim Nachmittag steht.
class Ganztagsstreifen extends StatelessWidget {
  /// Die sieben Tage der gezeigten Woche.
  final List<DateTime> tage;

  final List<Ganztagseintrag> eintraege;

  /// Breite der Stundenspalte links.
  final double zeitBreite;

  /// Feste Tagesbreite, oder null für gleichmäßige Verteilung. Die Kachel
  /// rechnet ihre Breite selbst aus, der Planner lässt verteilen.
  final double? tagBreite;

  /// Größere Schrift und Zeilen für ein Gerät an der Wand.
  final bool gross;

  const Ganztagsstreifen({
    super.key,
    required this.tage,
    required this.eintraege,
    required this.zeitBreite,
    this.tagBreite,
    this.gross = false,
  });

  double get _zeilenHoehe => gross ? 26.0 : 22.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final jeTag = [
      for (final tag in tage)
        eintraege.where((e) => e.liegtAuf(tag)).toList(),
    ];
    // Die Höhe wächst mit dem vollsten Tag. Feiertag UND Schulferien fallen
    // regelmäßig zusammen — zeigte man nur den ersten, verschwände einer
    // von beiden ohne Hinweis.
    final meiste = jeTag.fold<int>(0, (m, l) => l.length > m ? l.length : m);
    if (meiste == 0) return const SizedBox.shrink();

    Widget tagesspalte(int i) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final e in jeTag[i]) _kachel(theme, e),
          ],
        );

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: SizedBox(
        height: meiste * _zeilenHoehe + 6,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: zeitBreite,
              child: Padding(
                padding: const EdgeInsets.only(top: 5, right: 4),
                child: Text(
                  'ganztags',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor, fontSize: gross ? 11 : 9),
                ),
              ),
            ),
            for (var i = 0; i < tage.length; i++)
              if (tagBreite != null)
                SizedBox(width: tagBreite, child: tagesspalte(i))
              else
                Expanded(child: tagesspalte(i)),
          ],
        ),
      ),
    );
  }

  Widget _kachel(ThemeData theme, Ganztagseintrag e) {
    final kachel = Container(
      height: _zeilenHoehe - 4,
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: e.farbe.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        e.titel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: gross ? 12 : 10, color: Colors.white),
      ),
    );
    if (e.beiTipp == null) return kachel;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: e.beiTipp,
      child: kachel,
    );
  }
}

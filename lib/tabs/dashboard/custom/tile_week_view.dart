import 'package:flutter/material.dart';
import 'package:productivity/tabs/dashboard/custom/tile_data.dart';
import 'package:productivity/tabs/dashboard/custom/tile_views.dart';

/// Wochenraster als Kachel.
///
/// Angelehnt an die Wochenansicht im Planner — dasselbe Stundenraster mit
/// absolut gesetzten Terminen —, aber **ohne Ziehen und Bearbeiten**. Eine
/// Kachel wird gelesen, nicht bearbeitet; wer etwas ändern will, tippt sie
/// an und landet im Planner.
///
/// Zwei Unterschiede zur großen Ansicht, die aus der Größe folgen:
/// der Zeitbereich richtet sich nach den Terminen (ein leerer Vormittag
/// verschenkt sonst die halbe Kachel), und ganztägige Termine stehen als
/// Streifen über dem Raster statt darin.
class TileWeekView extends StatelessWidget {
  final TileData data;

  /// Tag, dessen Woche gezeigt wird. Ohne Angabe die laufende.
  final DateTime? woche;

  const TileWeekView({super.key, required this.data, this.woche});

  static const List<String> _tage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  DateTime get _wochenstart {
    // Reihenfolge mit Absicht: was ausdruecklich uebergeben wurde, dann was
    // die Quelle ausgewaehlt hat, erst zuletzt heute.
    final d = woche ?? data.anker ?? DateTime.now();
    final montag = d.subtract(Duration(days: d.weekday - 1));
    // Auf Mitternacht normalisieren, sonst fallen Termine vom Montagmorgen
    // aus dem Wochenfilter.
    return DateTime(montag.year, montag.month, montag.day);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final start = _wochenstart;

    final ganztags = data.schedule.where((e) => e.allDay).toList();
    final imRaster = data.schedule.where((e) => !e.allDay).toList();

    // Zeitbereich aus den Terminen statt 0–24 Uhr: in einer Kachel ist
    // Platz knapp, und ein leerer Vormittag verschenkt die halbe Fläche.
    //
    // Auf einer Küchenseite, wo die Wochenansicht allein die ganze Seite
    // füllt, gilt das nicht mehr: dort soll sie aussehen wie im Planner,
    // mit dem ganzen Tag und scrollbar. Entschieden wird das an der Höhe,
    // die tatsächlich zur Verfügung steht — nicht an einer Einstellung,
    // die noch jemand pflegen müsste.
    var vonStunde = 8;
    var bisStunde = 20;
    if (imRaster.isNotEmpty) {
      vonStunde = imRaster.map((e) => e.start.hour).reduce((a, b) => a < b ? a : b);
      bisStunde = imRaster
          .map((e) => e.end.hour + (e.end.minute > 0 ? 1 : 0))
          .reduce((a, b) => a > b ? a : b);
      vonStunde = (vonStunde - 1).clamp(0, 23);
      bisStunde = (bisStunde + 1).clamp(vonStunde + 3, 24);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Ab dieser Höhe ist Platz für den ganzen Tag – das ist der Fall,
        // wenn die Kachel eine Seite für sich hat.
        final grossflaechig = constraints.maxHeight >= _grosseAnsichtAb;
        final von = grossflaechig ? 0 : vonStunde;
        final bis = grossflaechig ? 24 : bisStunde;
        final anzahlStunden = bis - von;

        final zeitBreite = grossflaechig ? 52.0 : 34.0;
        final tagBreite = (constraints.maxWidth - zeitBreite) / 7;

        final kopfHoehe = grossflaechig ? _kopfHoeheGross : _kopfHoehe;
        final sichtbareHoehe = (constraints.maxHeight -
                kopfHoehe -
                (ganztags.isEmpty ? 0 : _ganztagsHoehe))
            .clamp(80.0, double.infinity);
        // Große Ansicht: feste Stundenhöhe wie im Planner und scrollbar.
        // Kleine: alles muss auf einmal hineinpassen.
        final stundenHoehe =
            grossflaechig ? _stundenHoeheGross : sichtbareHoehe / anzahlStunden;
        final rasterHoehe =
            grossflaechig ? stundenHoehe * anzahlStunden : sichtbareHoehe;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kopf(context, start, zeitBreite, tagBreite, grossflaechig),
            if (ganztags.isNotEmpty)
              _ganztagsStreifen(context, start, ganztags, zeitBreite, tagBreite),
            Expanded(
              child: SingleChildScrollView(
                child: SizedBox(
                  height: rasterHoehe,
                  child: Stack(
                    children: [
                      _raster(colors, von, anzahlStunden, stundenHoehe,
                          zeitBreite, tagBreite, grossflaechig),
                      for (final e in imRaster)
                        ..._termin(context, e, start, von, stundenHoehe,
                            zeitBreite, tagBreite),
                      ..._jetztLinie(colors, start, von, stundenHoehe,
                          zeitBreite, tagBreite),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Die Kopfzeile mit Wochentag und Datum.
  ///
  /// 34 statt 30: bei 30 lief die Spalte aus Wochentag und Tageszahl um
  /// genau einen Pixel ueber. In Release faellt das nicht auf, weil dort
  /// still abgeschnitten wird — im Debug sind es die Streifen. Gefunden
  /// hat es der erste Widget-Test dieses Projekts.
  static const double _kopfHoehe = 34;
  static const double _kopfHoeheGross = 52;
  static const double _ganztagsHoehe = 26;

  /// Ab dieser Höhe zeigt die Kachel den ganzen Tag statt eines Ausschnitts.
  ///
  /// Kein geratener Wert mehr: es ist das Mindestmaß dieser Darstellung
  /// mal [TileView.grossAb]. Wer das Mindestmaß ändert, ändert das hier
  /// mit — vorher standen beide Zahlen unabhängig voneinander im Code.
  static double get _grosseAnsichtAb =>
      TileViews.byKey('week')!.minHoehe * TileView.grossAb;

  /// Wie im Planner – dort sind es 64 Pixel je Stunde.
  static const double _stundenHoeheGross = 56;

  Widget _kopf(BuildContext context, DateTime start, double zeitBreite,
      double tagBreite, bool gross) {
    final colors = Theme.of(context).colorScheme;
    final heute = DateTime.now();

    return SizedBox(
      height: gross ? _kopfHoeheGross : _kopfHoehe,
      child: Row(
        children: [
          SizedBox(width: zeitBreite),
          for (var i = 0; i < 7; i++)
            SizedBox(
              width: tagBreite,
              child: Builder(builder: (_) {
                final tag = start.add(Duration(days: i));
                final istHeute = tag.year == heute.year &&
                    tag.month == heute.month &&
                    tag.day == heute.day;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_tage[i],
                        style: TextStyle(
                            fontSize: gross ? 13 : 10,
                            // Zeilenhoehe festgenagelt: mit der Vorgabe der
                            // Schrift passt die Spalte je nach Plattform
                            // gerade so nicht mehr.
                            height: 1.1,
                            color: istHeute ? colors.primary : colors.outline,
                            fontWeight:
                                istHeute ? FontWeight.bold : FontWeight.normal)),
                    Text('${tag.day}',
                        style: TextStyle(
                            fontSize: gross ? 18 : 12,
                            height: 1.15,
                            color: istHeute ? colors.primary : colors.onSurface,
                            fontWeight:
                                istHeute ? FontWeight.bold : FontWeight.w500)),
                  ],
                );
              }),
            ),
        ],
      ),
    );
  }

  /// Ganztägige Termine über dem Raster – im Raster hätten sie keine
  /// sinnvolle Höhe und würden alles andere verdecken.
  Widget _ganztagsStreifen(BuildContext context, DateTime start,
      List<TileScheduleItem> eintraege, double zeitBreite, double tagBreite) {
    return SizedBox(
      height: _ganztagsHoehe,
      child: Row(
        children: [
          SizedBox(width: zeitBreite),
          for (var i = 0; i < 7; i++)
            SizedBox(
              width: tagBreite,
              child: Builder(builder: (_) {
                final tag = start.add(Duration(days: i));
                final heute = eintraege.where((e) =>
                    e.start.year == tag.year &&
                    e.start.month == tag.month &&
                    e.start.day == tag.day);
                if (heute.isEmpty) return const SizedBox();
                final e = heute.first;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _farbe(context, e).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9, color: Colors.white),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _raster(ColorScheme colors, int vonStunde, int stunden,
      double stundenHoehe, double zeitBreite, double tagBreite, bool gross) {
    // Bei engem Raster nicht jede Stunde beschriften – sonst klebt die
    // Zeitspalte zu.
    final schritt = stundenHoehe < 22 ? 3 : (stundenHoehe < 34 ? 2 : 1);

    return Stack(
      children: [
        for (var i = 0; i < stunden; i++)
          Positioned(
            top: i * stundenHoehe,
            left: 0,
            right: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: zeitBreite,
                  child: (i % schritt == 0)
                      ? Text(
                          // In der großen Ansicht wie im Planner: 07:00
                          // statt einer nackten 7.
                          gross
                              ? '${(vonStunde + i).toString().padLeft(2, '0')}:00'
                              : '${vonStunde + i}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: gross ? 11 : 9, color: colors.outline))
                      : const SizedBox(),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: colors.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        for (var t = 1; t < 7; t++)
          Positioned(
            left: zeitBreite + t * tagBreite,
            top: 0,
            bottom: 0,
            child: Container(
                width: 1,
                color: colors.outlineVariant.withValues(alpha: 0.4)),
          ),
      ],
    );
  }

  List<Widget> _termin(BuildContext context, TileScheduleItem e, DateTime start,
      int vonStunde, double stundenHoehe, double zeitBreite, double tagBreite) {
    final tagIndex = DateTime(e.start.year, e.start.month, e.start.day)
        .difference(start)
        .inDays;
    if (tagIndex < 0 || tagIndex > 6) return const [];

    final beginn = (e.start.hour + e.start.minute / 60.0) - vonStunde;
    final dauer = e.end.difference(e.start).inMinutes / 60.0;
    // Mindesthöhe: ein Fünfminutentermin waere sonst ein Strich, den
    // niemand trifft und niemand liest.
    final hoehe = (dauer * stundenHoehe).clamp(14.0, double.infinity);

    return [
      Positioned(
        top: beginn * stundenHoehe,
        left: zeitBreite + tagIndex * tagBreite + 1,
        width: tagBreite - 2,
        height: hoehe,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: _farbe(context, e).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(4),
            border: Border(
                left: BorderSide(color: _farbe(context, e), width: 2.5)),
          ),
          child: Text(
            e.title,
            maxLines: hoehe > 28 ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, height: 1.15),
          ),
        ),
      ),
    ];
  }

  /// Die Linie „jetzt" – nur, wenn die laufende Woche gezeigt wird.
  List<Widget> _jetztLinie(ColorScheme colors, DateTime start, int vonStunde,
      double stundenHoehe, double zeitBreite, double tagBreite) {
    final jetzt = DateTime.now();
    final tagIndex =
        DateTime(jetzt.year, jetzt.month, jetzt.day).difference(start).inDays;
    if (tagIndex < 0 || tagIndex > 6) return const [];

    final oben = (jetzt.hour + jetzt.minute / 60.0 - vonStunde) * stundenHoehe;
    if (oben < 0) return const [];

    return [
      Positioned(
        top: oben,
        left: zeitBreite + tagIndex * tagBreite,
        width: tagBreite,
        child: Container(height: 2, color: const Color(0xFFE53935)),
      ),
    ];
  }

  Color _farbe(BuildContext context, TileScheduleItem e) {
    final roh = e.color;
    if (roh != null && roh.startsWith('#') && roh.length == 7) {
      final wert = int.tryParse(roh.substring(1), radix: 16);
      if (wert != null) return Color(0xFF000000 | wert);
    }
    return Theme.of(context).colorScheme.primary;
  }
}

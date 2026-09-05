import 'package:flutter/material.dart';
import 'package:productivity/tabs/dashboard/custom/tile_data.dart';

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
    final stunden = bisStunde - vonStunde;

    return LayoutBuilder(
      builder: (context, constraints) {
        final zeitBreite = 34.0;
        final tagBreite = (constraints.maxWidth - zeitBreite) / 7;
        final rasterHoehe = (constraints.maxHeight -
                _kopfHoehe -
                (ganztags.isEmpty ? 0 : _ganztagsHoehe))
            .clamp(80.0, double.infinity);
        final stundenHoehe = rasterHoehe / stunden;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kopf(context, start, zeitBreite, tagBreite),
            if (ganztags.isNotEmpty)
              _ganztagsStreifen(context, start, ganztags, zeitBreite, tagBreite),
            Expanded(
              child: SingleChildScrollView(
                child: SizedBox(
                  height: rasterHoehe,
                  child: Stack(
                    children: [
                      _raster(colors, vonStunde, stunden, stundenHoehe,
                          zeitBreite, tagBreite),
                      for (final e in imRaster)
                        ..._termin(context, e, start, vonStunde, stundenHoehe,
                            zeitBreite, tagBreite),
                      ..._jetztLinie(colors, start, vonStunde, stundenHoehe,
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

  static const double _kopfHoehe = 30;
  static const double _ganztagsHoehe = 26;

  Widget _kopf(BuildContext context, DateTime start, double zeitBreite,
      double tagBreite) {
    final colors = Theme.of(context).colorScheme;
    final heute = DateTime.now();

    return SizedBox(
      height: _kopfHoehe,
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
                            fontSize: 10,
                            color: istHeute ? colors.primary : colors.outline,
                            fontWeight:
                                istHeute ? FontWeight.bold : FontWeight.normal)),
                    Text('${tag.day}',
                        style: TextStyle(
                            fontSize: 12,
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
      double stundenHoehe, double zeitBreite, double tagBreite) {
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
                      ? Text('${vonStunde + i}',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 9, color: colors.outline))
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

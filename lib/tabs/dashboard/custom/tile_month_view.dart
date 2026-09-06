import 'package:flutter/material.dart';
import 'package:productivity/tabs/dashboard/custom/tile_data.dart';
import 'package:productivity/tabs/dashboard/custom/tile_views.dart';

/// Monatsraster als Kachel.
///
/// Vorbild ist die Monatsansicht im Planner (`views/month_view.dart`):
/// dasselbe Raster aus Wochenzeilen, derselbe Kopf mit Monatsnamen, dieselben
/// farbigen Streifen je Termin, dieselbe „+N mehr"-Zeile, wenn ein Tag
/// überläuft.
///
/// Der Unterschied ist derselbe wie bei der Wochenansicht: eine Kachel wird
/// **gelesen, nicht bearbeitet**. Kein Ziehen, kein Anlegen beim Tippen auf
/// eine Zelle — wer etwas ändern will, tippt die Kachel an und landet im
/// Planner. Was hier bleibt, ist der Knopf „+ Termin" am Kachelrand, und der
/// gehört zur Kachel, nicht zum Raster.
class TileMonthView extends StatelessWidget {
  final TileData data;

  /// Tag, dessen Monat gezeigt wird. Ohne Angabe der laufende.
  final DateTime? monat;

  /// Antippen oeffnet den Termin, wenn der Rueckkanal es anbietet.
  final TileKontext kontext;

  const TileMonthView({
    super.key,
    required this.data,
    this.monat,
    this.kontext = TileKontext.leer,
  });

  static const List<String> _wochentage = [
    'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So',
  ];

  static const List<String> _monatsnamen = [
    'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
    'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
  ];

  DateTime get _erster {
    // Wie bei der Wochenansicht: ausdrueckliche Angabe, sonst der Zeitraum,
    // den die Quelle ausgewaehlt hat, erst zuletzt heute.
    final d = monat ?? data.anker ?? DateTime.now();
    return DateTime(d.year, d.month);
  }

  int get _tageImMonat => DateTime(_erster.year, _erster.month + 1, 0).day;

  /// Mo = 1 … So = 7. Bestimmt, wie viele Zellen vorne leer bleiben.
  int get _ersterWochentag => _erster.weekday;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    final tage = _tageImMonat;
    final versatz = _ersterWochentag;
    final wochen = ((tage + versatz - 1) / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_monatsnamen[_erster.month - 1]} ${_erster.year}',
          textAlign: TextAlign.center,
          style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final t in _wochentage)
              Expanded(
                child: Center(
                  child: Text(
                    t,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colors.outline,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Column(
            children: [
              for (var woche = 0; woche < wochen; woche++)
                Expanded(
                  child: Row(
                    children: [
                      for (var wt = 0; wt < 7; wt++)
                        Expanded(
                          child: _zelle(context, woche * 7 + wt - versatz + 2),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _zelle(BuildContext context, int tagesnummer) {
    if (tagesnummer < 1 || tagesnummer > _tageImMonat) {
      return const SizedBox();
    }

    final colors = Theme.of(context).colorScheme;
    final tag = DateTime(_erster.year, _erster.month, tagesnummer);
    final jetzt = DateTime.now();
    final istHeute = tag.year == jetzt.year &&
        tag.month == jetzt.month &&
        tag.day == jetzt.day;

    final eintraege = data.schedule
        .where((e) =>
            e.start.year == tag.year &&
            e.start.month == tag.month &&
            e.start.day == tag.day)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return Container(
      margin: const EdgeInsets.all(1.5),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: istHeute ? colors.primary.withValues(alpha: 0.08) : null,
        border: Border.all(
          color: istHeute
              ? colors.primary
              : colors.outlineVariant.withValues(alpha: 0.6),
          width: istHeute ? 1.4 : 1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      // Die Zelle richtet sich nach ihrer Hoehe. In einem Monatsraster auf
      // einer kleinen Kachel bleiben je Tag keine dreissig Pixel — dort
      // passt die Tageszahl und sonst nichts, und das muss sie sagen
      // duerfen, statt ueberzulaufen.
      child: LayoutBuilder(
        builder: (context, zelle) {
          final zahlHoehe = zelle.maxHeight < 30 ? 12.0 : 18.0;
          final platzFuerTermine = zelle.maxHeight - zahlHoehe - 2;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: zahlHoehe,
                  height: zahlHoehe,
                  alignment: Alignment.center,
                  decoration: istHeute
                      ? BoxDecoration(
                          color: colors.primary, shape: BoxShape.circle)
                      : null,
                  child: FittedBox(
                    child: Text(
                      '$tagesnummer',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.0,
                        fontWeight:
                            istHeute ? FontWeight.bold : FontWeight.normal,
                        color: istHeute ? colors.onPrimary : colors.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              // Unter etwa zehn Pixeln passt kein Streifen mehr hinein –
              // dann lieber gar keiner als ein abgeschnittener.
              if (platzFuerTermine >= 10)
                Expanded(child: _eintraege(context, eintraege)),
            ],
          );
        },
      ),
    );
  }

  /// So viele Streifen, wie in die Zelle passen — der Rest als „+N".
  ///
  /// Ohne das Nachrechnen liefe die Zelle über und Flutter meldete einen
  /// Überlauf quer durch die Kachel. In einer Kachel ist deutlich weniger
  /// Platz als in der großen Ansicht, deshalb steht die Rechnung hier.
  Widget _eintraege(BuildContext context, List<TileScheduleItem> eintraege) {
    if (eintraege.isEmpty) return const SizedBox();

    return LayoutBuilder(
      builder: (context, constraints) {
        const streifen = 13.0;
        final passen =
            (constraints.maxHeight / streifen).floor().clamp(0, eintraege.length);
        final zeigen =
            eintraege.length > passen && passen > 0 ? passen - 1 : passen;
        final versteckt = eintraege.length - zeigen;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final e in eintraege.take(zeigen)) _streifen(context, e),
            if (versteckt > 0)
              Text(
                '+$versteckt',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _streifen(BuildContext context, TileScheduleItem e) {
    final f = kontext.terminOeffnen;
    final streifen = _streifenInhalt(context, e);
    if (f == null || e.id == 0) return streifen;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => f(e.id),
      child: streifen,
    );
  }

  Widget _streifenInhalt(BuildContext context, TileScheduleItem e) {
    return Container(
      height: 11,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: _farbe(context, e),
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        // Ganztägiges hat keine Uhrzeit, die etwas sagen würde.
        e.allDay ? e.title : '${_uhr(e.start)} ${e.title}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static String _uhr(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Color _farbe(BuildContext context, TileScheduleItem e) {
    final roh = e.color;
    if (roh != null && roh.startsWith('#') && roh.length == 7) {
      final wert = int.tryParse(roh.substring(1), radix: 16);
      if (wert != null) return Color(0xFF000000 | wert);
    }
    return Theme.of(context).colorScheme.primary;
  }
}

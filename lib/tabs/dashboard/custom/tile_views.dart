import 'package:flutter/material.dart';
import 'package:productivity/tabs/dashboard/custom/tile_charts.dart';
import 'package:productivity/tabs/dashboard/custom/tile_week_view.dart';
import 'package:productivity/tabs/dashboard/custom/tile_data.dart';

/// Eine Darstellungsart im Katalog.
///
/// `accepts` entscheidet, welche Quellen dazu passen — die Oberfläche bietet
/// beim Anlegen nur passende Kombinationen an. Eine gepflegte Liste erlaubter
/// Paarungen braucht es dadurch nicht.
class TileView {
  final String key;
  final String label;
  final IconData icon;
  final Set<TileShape> accepts;
  final Widget Function(BuildContext context, TileData data) build;

  const TileView({
    required this.key,
    required this.label,
    required this.icon,
    required this.accepts,
    required this.build,
  });
}

class TileViews {
  TileViews._();

  static final List<TileView> all = [
    TileView(
      key: 'stat',
      label: 'Große Zahl',
      icon: Icons.numbers_rounded,
      accepts: const {TileShape.scalar},
      build: (ctx, d) => _Stat(data: d),
    ),
    TileView(
      key: 'list',
      label: 'Liste',
      icon: Icons.format_list_bulleted_rounded,
      accepts: const {TileShape.list},
      build: (ctx, d) => _List(data: d),
    ),
    TileView(
      key: 'text',
      label: 'Text',
      icon: Icons.notes_rounded,
      accepts: const {TileShape.text},
      build: (ctx, d) => _Text(data: d),
    ),
    TileView(
      key: 'week',
      label: 'Wochenansicht',
      icon: Icons.calendar_view_week_rounded,
      accepts: const {TileShape.schedule},
      build: (ctx, d) => TileWeekView(data: d),
    ),
    TileView(
      key: 'bars',
      label: 'Balkendiagramm',
      icon: Icons.bar_chart_rounded,
      accepts: const {TileShape.series, TileShape.distribution},
      build: (ctx, d) => TileBarChart(data: d),
    ),
    TileView(
      key: 'line',
      label: 'Liniendiagramm',
      icon: Icons.show_chart_rounded,
      // Nur Verlaeufe: eine Linie durch Kategorien zu ziehen suggeriert
      // einen Zusammenhang, den es nicht gibt.
      accepts: const {TileShape.series},
      build: (ctx, d) => TileLineChart(data: d),
    ),
    TileView(
      key: 'pie',
      label: 'Tortendiagramm',
      icon: Icons.pie_chart_rounded,
      // Nur Verteilungen: ein Kuchenstueck je Tag waere zeichenbar, wuerde
      // aber nichts aussagen.
      accepts: const {TileShape.distribution},
      build: (ctx, d) => TilePieChart(data: d),
    ),
    TileView(
      key: 'donut',
      label: 'Ringdiagramm',
      icon: Icons.donut_large_rounded,
      accepts: const {TileShape.distribution},
      build: (ctx, d) => TilePieChart(data: d, alsRing: true),
    ),
  ];

  static TileView? byKey(String key) {
    for (final v in all) {
      if (v.key == key) return v;
    }
    return null;
  }

  /// Darstellungen, die zu dieser Datenform passen.
  static List<TileView> forShape(TileShape shape) =>
      all.where((v) => v.accepts.contains(shape)).toList();
}

// ── Große Zahl ──────────────────────────────────────────────────────────────
class _Stat extends StatelessWidget {
  final TileData data;
  const _Stat({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final v = data.value ?? 0;
    final zahl = v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(zahl,
            style: text.displaySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.primary,
            )),
        if (data.unit != null) ...[
          const SizedBox(width: 8),
          Text(data.unit!, style: text.titleMedium?.copyWith(
                color: colors.onSurfaceVariant,
              )),
        ],
      ],
    );
  }
}

// ── Liste ───────────────────────────────────────────────────────────────────
class _List extends StatelessWidget {
  final TileData data;
  const _List({required this.data});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in data.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.title,
                          style: text.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (item.subtitle != null)
                        Text(item.subtitle!,
                            style: text.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            )),
                    ],
                  ),
                ),
                if (item.trailing != null)
                  Text(item.trailing!, style: text.labelMedium),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Balken ──────────────────────────────────────────────────────────────────
/// Von Hand gezeichnet statt mit einem Diagramm-Paket: die App hat keines,
/// und für Balken lohnt eine weitere Abhängigkeit über sechs Plattformen nicht.

/// Freier Text – vom Nutzer geschrieben oder aus den eigenen Daten geholt.
class _Text extends StatelessWidget {
  final TileData data;

  const _Text({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          data.body ?? '',
          // Groesser als Fliesstext: diese Bloecke stehen ganz oben und
          // sollen im Vorbeigehen lesbar sein, nicht studiert werden.
          style: text.bodyLarge?.copyWith(height: 1.45),
        ),
        if (data.footnote != null) ...[
          const SizedBox(height: 8),
          Text(
            data.footnote!,
            style: text.bodySmall?.copyWith(color: colors.outline),
          ),
        ],
      ],
    );
  }
}

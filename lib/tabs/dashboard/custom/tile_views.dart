import 'package:flutter/material.dart';
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
      key: 'bars',
      label: 'Balkendiagramm',
      icon: Icons.bar_chart_rounded,
      accepts: const {TileShape.series, TileShape.distribution},
      build: (ctx, d) => _Bars(data: d),
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
class _Bars extends StatelessWidget {
  final TileData data;
  const _Bars({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final maxWert = data.points.values.fold<double>(0, (a, b) => b > a ? b : a);
    final teiler = maxWert <= 0 ? 1.0 : maxWert;

    return SizedBox(
      height: 130,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final eintrag in data.points.entries)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _kurz(eintrag.value),
                      style: text.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    // Mindesthöhe, damit ein Nullwert nicht unsichtbar wird.
                    Container(
                      height: (eintrag.value / teiler * 78).clamp(3.0, 78.0),
                      decoration: BoxDecoration(
                        color: eintrag.value > 0
                            ? colors.primary
                            : colors.outlineVariant,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      eintrag.key,
                      style: text.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _kurz(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
}

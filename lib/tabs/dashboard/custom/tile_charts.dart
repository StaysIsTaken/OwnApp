import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:productivity/tabs/dashboard/custom/tile_data.dart';

/// Die Diagramme für selbst zusammengestellte Kacheln.
///
/// Eine gemeinsame Farbreihe für alles, damit dieselbe Kategorie in
/// verschiedenen Kacheln nicht plötzlich die Farbe wechselt: die Farbe hängt
/// am Rang im Datensatz, nicht am Zufall.
List<Color> _reihe(ColorScheme c) => [
      c.primary,
      c.tertiary,
      c.secondary,
      c.primary.withValues(alpha: 0.55),
      c.tertiary.withValues(alpha: 0.55),
      c.secondary.withValues(alpha: 0.55),
      c.outline,
    ];

String _kurz(double v) {
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}

/// Balkendiagramm — für Verläufe über die Zeit und für Verteilungen.
class TileBarChart extends StatelessWidget {
  final TileData data;

  const TileBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final farben = _reihe(colors);
    final eintraege = data.points.entries.toList();
    final max = eintraege.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: max <= 0 ? 1 : max * 1.2,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: colors.outlineVariant, strokeWidth: 0.5),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (wert, meta) => Text(
                  _kurz(wert),
                  style: TextStyle(fontSize: 10, color: colors.outline),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (wert, meta) {
                  final i = wert.toInt();
                  if (i < 0 || i >= eintraege.length) return const SizedBox();
                  // Bei vielen Balken nur jede zweite Beschriftung, sonst
                  // ueberlappen sie und man liest gar nichts mehr.
                  final schritt = eintraege.length > 8 ? 2 : 1;
                  if (i % schritt != 0) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      eintraege[i].key,
                      style: TextStyle(fontSize: 9, color: colors.outline),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (gruppe, gruppenIndex, stab, stabIndex) => BarTooltipItem(
                '${eintraege[gruppe.x].key}\n${_kurz(stab.toY)}'
                '${data.unit == null ? "" : " ${data.unit}"}',
                TextStyle(color: colors.onInverseSurface, fontSize: 12),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < eintraege.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: eintraege[i].value,
                  color: farben[i % farben.length],
                  width: eintraege.length > 12 ? 8 : 14,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4)),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

/// Tortendiagramm — nur für Verteilungen sinnvoll.
///
/// Bei einem Verlauf über die Zeit wäre ein Kuchenstück je Tag zwar
/// zeichenbar, würde aber nichts aussagen. Deshalb nimmt diese Darstellung
/// `series` gar nicht erst an.
class TilePieChart extends StatefulWidget {
  final TileData data;
  final bool alsRing;

  const TilePieChart({super.key, required this.data, this.alsRing = false});

  @override
  State<TilePieChart> createState() => _TilePieChartState();
}

class _TilePieChartState extends State<TilePieChart> {
  int? _beruehrt;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final farben = _reihe(colors);
    final eintraege = widget.data.points.entries
        .where((e) => e.value > 0)
        .toList();
    final summe = eintraege.fold<double>(0, (a, e) => a + e.value);

    return SizedBox(
      height: 170,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: widget.alsRing ? 34 : 0,
                pieTouchData: PieTouchData(
                  touchCallback: (ereignis, antwort) => setState(() {
                    _beruehrt = ereignis.isInterestedForInteractions
                        ? antwort?.touchedSection?.touchedSectionIndex
                        : null;
                  }),
                ),
                sections: [
                  for (var i = 0; i < eintraege.length; i++)
                    PieChartSectionData(
                      value: eintraege[i].value,
                      color: farben[i % farben.length],
                      radius: _beruehrt == i ? 62 : 55,
                      // Beschriftung nur bei Stuecken, die gross genug sind –
                      // sonst steht die Zahl halb ausserhalb des Kuchens.
                      showTitle: eintraege[i].value / summe > 0.08,
                      title: '${(eintraege[i].value / summe * 100).round()}%',
                      titleStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.onPrimary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Legende: ohne sie sagen die Farben nichts.
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < eintraege.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: farben[i % farben.length],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              eintraege[i].key,
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _kurz(eintraege[i].value),
                            style: TextStyle(
                                fontSize: 11,
                                color: colors.outline,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Liniendiagramm — für Verläufe über die Zeit.
class TileLineChart extends StatelessWidget {
  final TileData data;

  const TileLineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final eintraege = data.points.entries.toList();
    final max = eintraege.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: max <= 0 ? 1 : max * 1.2,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: colors.outlineVariant, strokeWidth: 0.5),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (wert, meta) => Text(
                  _kurz(wert),
                  style: TextStyle(fontSize: 10, color: colors.outline),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (wert, meta) {
                  final i = wert.toInt();
                  if (i < 0 || i >= eintraege.length) return const SizedBox();
                  final schritt = eintraege.length > 8 ? 2 : 1;
                  if (i % schritt != 0) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(eintraege[i].key,
                        style: TextStyle(fontSize: 9, color: colors.outline)),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < eintraege.length; i++)
                  FlSpot(i.toDouble(), eintraege[i].value),
              ],
              isCurved: true,
              curveSmoothness: 0.25,
              color: colors.primary,
              barWidth: 2.5,
              dotData: FlDotData(show: eintraege.length <= 14),
              belowBarData: BarAreaData(
                show: true,
                color: colors.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

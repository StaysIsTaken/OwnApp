import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/planner_entry.dart';

/// Zeigt die heutigen Planner-Termine als kompakte Timeline.
class TodayAgendaWidget extends StatelessWidget {
  final List<PlannerEntry> entries; // heutige Termine (unsortiert ok)
  const TodayAgendaWidget({super.key, required this.entries});

  Color _parseColor(String hex) {
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    try {
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return Colors.blueAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final df = DateFormat('HH:mm');
    final sorted = [...entries]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return Card(
      elevation: 0,
      color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_note_rounded, color: colors.primary),
                const SizedBox(width: 8),
                Text('Heute',
                    style: text.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (sorted.isNotEmpty)
                  Text('${sorted.length} Termin${sorted.length == 1 ? '' : 'e'}',
                      style: text.labelSmall
                          ?.copyWith(color: colors.onSurfaceVariant)),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.planner),
                  child: const Text('Planner'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (sorted.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Keine Termine heute 🎉',
                    style: text.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant)),
              )
            else
              ...sorted.map((e) {
                final c = _parseColor(e.color);
                final isPast = e.endsAt.isBefore(now);
                final isNow =
                    e.scheduledAt.isBefore(now) && e.endsAt.isAfter(now);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Opacity(
                    opacity: isPast ? 0.45 : 1,
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 96,
                          child: Text(
                            '${df.format(e.scheduledAt)}–${df.format(e.endsAt)}',
                            style: text.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium?.copyWith(
                              fontWeight:
                                  isNow ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isNow)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('jetzt',
                                style: text.labelSmall
                                    ?.copyWith(color: colors.onPrimary)),
                          ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

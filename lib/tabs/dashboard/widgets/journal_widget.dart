import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/journal_entry.dart';

class JournalWidget extends StatelessWidget {
  final List<JournalEntry> journalEntries;
  final double? averageSentiment;
  final int positiveCount;
  final int neutralCount;
  final int negativeCount;
  final List<Map<String, dynamic>> topTopics;

  const JournalWidget({
    super.key,
    required this.journalEntries,
    this.averageSentiment,
    required this.positiveCount,
    required this.neutralCount,
    required this.negativeCount,
    required this.topTopics,
  });

  int get _totalAnalyzed => positiveCount + neutralCount + negativeCount;
  bool get _hasAnalysis => _totalAnalyzed > 0;

  String _getSentimentEmoji(double? score) {
    if (score == null) return '😐';
    if (score > 0.5) return '😊';
    if (score > 0.2) return '🙂';
    if (score > -0.2) return '😐';
    if (score > -0.5) return '😕';
    return '😢';
  }

  Color _getSentimentColor(double? score) {
    if (score == null) return Colors.grey;
    if (score > 0.3) return Colors.green;
    if (score < -0.3) return Colors.red;
    return Colors.orange;
  }

  String _getSentimentLabel(double? score) {
    if (score == null) return 'Keine Analyse';
    if (score > 0.3) return 'Positiv';
    if (score < -0.3) return 'Negativ';
    return 'Neutral';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final recentEntries = List<JournalEntry>.from(journalEntries)
      ..sort((a, b) => b.date.compareTo(a.date));

    return _DashboardCard(
      onTap: () => Navigator.pushNamed(context, AppRoutes.journal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.book_outlined, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Journal',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${journalEntries.length}',
                style: text.titleMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: colors.outline),
            ],
          ),
          const SizedBox(height: 12),

          // Sentiment-Analyse (falls vorhanden)
          if (_hasAnalysis) ...[
            _buildSentimentSection(colors, text),
            const SizedBox(height: 12),
          ],

          // Letzte Einträge
          if (journalEntries.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_note, color: colors.onSurfaceVariant, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Noch keine Journal-Einträge vorhanden',
                      style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            )
          else
            ...recentEntries.take(3).map((entry) => _buildEntryItem(entry, colors, text)),

          if (journalEntries.length > 3) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                '+ ${journalEntries.length - 3} weitere Einträge',
                style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSentimentSection(ColorScheme colors, TextTheme text) {
    final sentimentColor = _getSentimentColor(averageSentiment);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: sentimentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sentimentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(_getSentimentEmoji(averageSentiment), style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stimmung: ${_getSentimentLabel(averageSentiment)}',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: sentimentColor,
                      ),
                    ),
                    Text(
                      'Letzte 30 Tage · $_totalAnalyzed analysiert',
                      style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Verteilungsbalken
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                if (positiveCount > 0)
                  Expanded(
                    flex: positiveCount,
                    child: Container(height: 6, color: Colors.green),
                  ),
                if (neutralCount > 0)
                  Expanded(
                    flex: neutralCount,
                    child: Container(height: 6, color: Colors.orange),
                  ),
                if (negativeCount > 0)
                  Expanded(
                    flex: negativeCount,
                    child: Container(height: 6, color: Colors.red),
                  ),
              ],
            ),
          ),
          if (topTopics.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: topTopics.take(4).map((topic) {
                final name = topic['name'] ?? topic['topic'] ?? '';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    name.toString(),
                    style: text.labelSmall,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEntryItem(JournalEntry entry, ColorScheme colors, TextTheme text) {
    final preview = entry.content.length > 80
        ? '${entry.content.substring(0, 80)}...'
        : entry.content;
    final dateStr = DateFormat('dd. MMM', 'de_DE').format(entry.date);
    final isToday = _isToday(entry.date);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isToday
              ? colors.primary.withValues(alpha: 0.08)
              : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: colors.primary.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isToday ? colors.primary : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isToday ? 'Heute' : dateStr,
                style: text.labelSmall?.copyWith(
                  color: isToday ? colors.onPrimary : colors.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                preview,
                style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}

class _DashboardCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _DashboardCard({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

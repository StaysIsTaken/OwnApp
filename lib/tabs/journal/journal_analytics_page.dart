import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:productivity/dataclasses/journal_analysis.dart';
import 'package:productivity/dataservice/journal_analysis_service.dart';

class JournalAnalyticsPage extends StatefulWidget {
  const JournalAnalyticsPage({super.key});

  @override
  State<JournalAnalyticsPage> createState() => _JournalAnalyticsPageState();
}

class _JournalAnalyticsPageState extends State<JournalAnalyticsPage> {
  List<JournalAnalysis> _analyses = [];
  bool _isLoading = true;
  String? _error;
  DateTimeRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedRange = DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final analyses = await JournalAnalysisService.getAnalysesByDateRange(
        dateFrom: _selectedRange?.start,
        dateTo: _selectedRange?.end,
      );
      setState(() {
        _analyses = analyses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, int> _getTopics() {
    final topics = <String, int>{};
    for (final analysis in _analyses) {
      for (final topic in analysis.detectedTopics) {
        topics[topic] = (topics[topic] ?? 0) + 1;
      }
    }
    return Map.fromEntries(
      topics.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  double _getAverageSentiment() {
    if (_analyses.isEmpty) return 0;
    final sum = _analyses.fold<double>(0, (acc, a) => acc + (a.sentimentScore ?? 0));
    return sum / _analyses.length;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal Analyse'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalytics,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date range selector
              Card(
                color: colors.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Zeitraum', style: text.titleSmall),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedRange != null
                                  ? '${DateFormat('dd.MM.yyyy', 'de_DE').format(_selectedRange!.start)} - ${DateFormat('dd.MM.yyyy', 'de_DE').format(_selectedRange!.end)}'
                                  : 'Zeitraum wählen',
                              style: text.bodyMedium,
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () async {
                              final range = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                                initialDateRange: _selectedRange,
                              );
                              if (range != null) {
                                setState(() => _selectedRange = range);
                                await _loadAnalytics();
                              }
                            },
                            icon: const Icon(Icons.date_range),
                            label: const Text('Ändern'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (_isLoading)
                Center(
                  child: CircularProgressIndicator(color: colors.primary),
                )
              else if (_error != null)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: colors.error),
                      const SizedBox(height: 16),
                      Text('Fehler beim Laden',
                          style: text.bodyMedium?.copyWith(color: colors.error)),
                    ],
                  ),
                )
              else if (_analyses.isEmpty)
                Center(
                  child: Text(
                    'Keine Analysen verfügbar',
                    style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                  ),
                )
              else ...[
                // Average sentiment
                Card(
                  color: colors.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Durchschnittliche Stimmung', style: text.titleSmall),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _getAverageSentiment() > 0
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : _getAverageSentiment() < 0
                                        ? Colors.red.withValues(alpha: 0.2)
                                        : Colors.grey.withValues(alpha: 0.2),
                              ),
                              child: Center(
                                child: Text(
                                  _getAverageSentiment() > 0 ? '😊' : _getAverageSentiment() < 0 ? '😔' : '😐',
                                  style: const TextStyle(fontSize: 32),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getAverageSentiment().toStringAsFixed(2),
                                    style: text.headlineSmall,
                                  ),
                                  Text(
                                    'auf einer Skala von -1 bis +1',
                                    style: text.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Sentiment distribution
                Card(
                  color: colors.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stimmungsverteilung', style: text.titleSmall),
                        const SizedBox(height: 12),
                        _buildSentimentStats(colors, text),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Top topics
                if (_getTopics().isNotEmpty) ...[
                  Card(
                    color: colors.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Häufigste Themen', style: text.titleSmall),
                          const SizedBox(height: 12),
                          ..._getTopics().entries.take(5).map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(child: Text(entry.key)),
                                  Chip(
                                    label: Text('${entry.value}x'),
                                    backgroundColor: colors.primaryContainer,
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSentimentStats(ColorScheme colors, TextTheme text) {
    final positive = _analyses.where((a) => (a.sentimentScore ?? 0) > 0.3).length;
    final neutral = _analyses.where((a) => (a.sentimentScore ?? 0) >= -0.3 && (a.sentimentScore ?? 0) <= 0.3).length;
    final negative = _analyses.where((a) => (a.sentimentScore ?? 0) < -0.3).length;
    final total = _analyses.length;

    return Column(
      children: [
        _buildStatRow(
          emoji: '😊',
          label: 'Positiv',
          count: positive,
          total: total,
          color: Colors.green,
          text: text,
        ),
        const SizedBox(height: 12),
        _buildStatRow(
          emoji: '😐',
          label: 'Neutral',
          count: neutral,
          total: total,
          color: Colors.grey,
          text: text,
        ),
        const SizedBox(height: 12),
        _buildStatRow(
          emoji: '😔',
          label: 'Negativ',
          count: negative,
          total: total,
          color: Colors.red,
          text: text,
        ),
      ],
    );
  }

  Widget _buildStatRow({
    required String emoji,
    required String label,
    required int count,
    required int total,
    required Color color,
    required TextTheme text,
  }) {
    final percentage = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0.0';

    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.bodySmall),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total > 0 ? count / total : 0,
                  minHeight: 6,
                  backgroundColor: color.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$count ($percentage%)',
          style: text.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:productivity/dataclasses/journal_entry.dart';
import 'package:productivity/dataclasses/journal_analysis.dart';
import 'package:productivity/dataservice/journal_service.dart';
import 'package:productivity/dataservice/journal_analysis_service.dart';
import 'package:productivity/dataservice/login_service.dart';

class JournalEntryPage extends StatefulWidget {
  final JournalEntry? entry;
  final DateTime date;
  final VoidCallback onSaved;
  final bool readOnly;

  const JournalEntryPage({
    super.key,
    this.entry,
    required this.date,
    required this.onSaved,
    this.readOnly = false,
  });

  @override
  State<JournalEntryPage> createState() => _JournalEntryPageState();
}

class _JournalEntryPageState extends State<JournalEntryPage> {
  late TextEditingController _contentController;
  JournalAnalysis? _analysis;
  bool _loadingAnalysis = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.entry?.content ?? '');
    if (widget.entry != null) {
      _loadAnalysis();
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalysis() async {
    if (widget.entry == null) return;

    setState(() => _loadingAnalysis = true);
    try {
      final analysis = await JournalAnalysisService.getAnalysis(widget.entry!.id);
      if (mounted) {
        setState(() => _analysis = analysis);
      }
    } catch (e) {
      // Handle error silently - analysis may not be available yet
    } finally {
      if (mounted) {
        setState(() => _loadingAnalysis = false);
      }
    }
  }

  Future<void> _saveEntry() async {
    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eintrag kann nicht leer sein')),
      );
      return;
    }

    try {
      final user = await LoginService.currentUser;

      if (widget.entry != null) {
        final updated = widget.entry!.copyWith(
          content: _contentController.text,
          updatedAt: DateTime.now(),
        );
        await JournalService.update(updated);
      } else {
        final newEntry = JournalEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: user.id,
          content: _contentController.text,
          date: widget.date,
          createdAt: DateTime.now(),
        );
        await JournalService.create(newEntry);
      }

      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eintrag gespeichert')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          DateFormat('dd. MMMM yyyy', 'de_DE').format(widget.date),
        ),
        actions: [
          if (!widget.readOnly)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveEntry,
              tooltip: 'Speichern',
            ),
        ],
      ),
      body: isMobile
          ? _buildMobileLayout(colors, text)
          : _buildDesktopLayout(colors, text),
    );
  }

  Widget _buildMobileLayout(ColorScheme colors, TextTheme text) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Text input
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _contentController,
                readOnly: widget.readOnly,
                decoration: InputDecoration(
                  hintText: 'Schreibe auf, wie du dich fühlst...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                  filled: widget.readOnly,
                  fillColor: widget.readOnly ? colors.surfaceContainerHighest : null,
                ),
                maxLines: null,
                expands: true,
              ),
            ),
            const SizedBox(height: 16),

            // Analysis card
            if (_analysis != null || widget.entry != null)
              _buildAnalysisCard(colors, text),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(ColorScheme colors, TextTheme text) {
    return Row(
      children: [
        // Text input
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _contentController,
                readOnly: widget.readOnly,
                decoration: InputDecoration(
                  hintText: 'Schreibe auf, wie du dich fühlst...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  filled: widget.readOnly,
                  fillColor: widget.readOnly ? colors.surfaceContainerHighest : null,
                ),
                maxLines: null,
                expands: true,
              ),
            ),
          ),
        ),

        // Analysis panel
        if (_analysis != null || widget.entry != null)
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildAnalysisCard(colors, text),
            ),
          ),
      ],
    );
  }

  Widget _buildAnalysisCard(ColorScheme colors, TextTheme text) {
    if (_loadingAnalysis) {
      return Center(
        child: CircularProgressIndicator(color: colors.primary),
      );
    }

    if (_analysis == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analyse',
              style: text.titleSmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Speichern Sie Ihren Eintrag, um eine KI-Analyse zu erhalten.',
              style: text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _analysis!.getSentimentColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _analysis!.getSentimentColor().withValues(alpha: 0.3),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _analysis!.getSentimentEmoji(),
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stimmung',
                        style: text.labelSmall,
                      ),
                      Text(
                        _analysis!.getSentimentText(),
                        style: text.titleSmall?.copyWith(
                          color: _analysis!.getSentimentColor(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_analysis!.detectedTopics.isNotEmpty) ...[
              Text(
                'Themen',
                style: text.labelSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _analysis!.detectedTopics
                    .map(
                      (topic) => Chip(
                        label: Text(topic),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
            if (_analysis!.summary != null) ...[
              Text(
                'Zusammenfassung',
                style: text.labelSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _analysis!.summary!,
                style: text.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

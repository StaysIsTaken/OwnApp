import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:productivity/dataclasses/journal_entry.dart';
import 'package:productivity/dataservice/journal_service.dart';
import 'package:productivity/main.dart';
import 'journal_entry_page.dart';

class JournalPage extends BasePage {
  const JournalPage({super.key}) : super(title: 'Journal');

  @override
  Widget buildBody(BuildContext context) => const _JournalPageContent();
}

class _JournalPageContent extends StatefulWidget {
  const _JournalPageContent();

  @override
  State<_JournalPageContent> createState() => _JournalPageContentState();
}

class _JournalPageContentState extends State<_JournalPageContent> {
  List<JournalEntry> _entries = [];
  bool _isLoading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final entries = await JournalService.loadAll();
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  JournalEntry? _getTodayEntry() {
    try {
      return _entries.firstWhere(
        (e) =>
            e.date.year == _selectedDate.year &&
            e.date.month == _selectedDate.month &&
            e.date.day == _selectedDate.day,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final todayEntry = _getTodayEntry();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Date selector
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      DateFormat('dd. MMMM yyyy', 'de_DE')
                          .format(_selectedDate),
                      style: text.bodyMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JournalEntryPage(
                        entry: todayEntry,
                        date: _selectedDate,
                        onSaved: _loadEntries,
                      ),
                    ),
                  );
                },
                icon: Icon(todayEntry != null ? Icons.edit : Icons.add),
                label: Text(
                  todayEntry != null ? 'Bearbeiten' : 'Neuer Eintrag',
                ),
              ),
            ],
          ),
        ),

        // Current entry preview
        if (todayEntry != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: colors.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Heute',
                      style: text.titleSmall?.copyWith(color: colors.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      todayEntry.content.length > 200
                          ? '${todayEntry.content.substring(0, 200)}...'
                          : todayEntry.content,
                      style: text.bodyMedium,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),

        const SizedBox(height: 24),

        // All entries
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Alle Einträge', style: text.titleMedium),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: _buildEntriesList(colors, text),
        ),
      ],
    );
  }

  Widget _buildEntriesList(ColorScheme colors, TextTheme text) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: colors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.error),
            const SizedBox(height: 16),
            Text('Fehler beim Laden',
                style: text.bodyMedium?.copyWith(color: colors.error)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadEntries,
              icon: const Icon(Icons.refresh),
              label: const Text('Erneut versuchen'),
            ),
          ],
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Text(
          'Keine Einträge vorhanden',
          style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEntries,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: colors.surfaceContainerHighest,
            child: ListTile(
              title: Text(
                DateFormat('dd. MMMM yyyy', 'de_DE').format(entry.date),
                style: text.titleSmall,
              ),
              subtitle: Text(
                entry.content.length > 100
                    ? '${entry.content.substring(0, 100)}...'
                    : entry.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Text('Lesen'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => JournalEntryPage(
                            entry: entry,
                            date: entry.date,
                            onSaved: _loadEntries,
                            readOnly: true,
                          ),
                        ),
                      );
                    },
                  ),
                  PopupMenuItem(
                    child: const Text('Bearbeiten'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => JournalEntryPage(
                            entry: entry,
                            date: entry.date,
                            onSaved: _loadEntries,
                          ),
                        ),
                      );
                    },
                  ),
                  PopupMenuItem(
                    child: const Text('Löschen'),
                    onTap: () => _deleteEntry(entry),
                  ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => JournalEntryPage(
                      entry: entry,
                      date: entry.date,
                      onSaved: _loadEntries,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteEntry(JournalEntry entry) async {
    try {
      await JournalService.delete(entry.id);
      await _loadEntries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eintrag gelöscht')),
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
}

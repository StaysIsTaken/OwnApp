import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:productivity/dataclasses/time_entry.dart';
import 'package:productivity/main.dart';
import 'package:productivity/widgets/time_input_dialog.dart';

class TimePage extends BasePage {
  const TimePage({super.key}) : super(title: 'Zeiten');

  @override
  Widget buildBody(BuildContext context) => const _TimePageContent();
}

class _TimePageContent extends StatefulWidget {
  const _TimePageContent();

  @override
  State<_TimePageContent> createState() => _TimePageState();
}

class _TimePageState extends State<_TimePageContent> {
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _filterDate = 'today';
  TimeEntry? _editingEntry;

  final List<TimeEntry> _entries = [];

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _addEntry() {
    if (_startTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bitte Startzeit wählen')));
      return;
    }

    if (_editingEntry != null) {
      setState(() {
        final updatedEntry = _editingEntry!.copyWith(
          date: _selectedDate,
          startTime: DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            _startTime!.hour,
            _startTime!.minute,
          ),
          endTime: _endTime != null
              ? DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                  _endTime!.hour,
                  _endTime!.minute,
                )
              : null,
          description: _descriptionController.text,
        );
        final index = _entries.indexOf(_editingEntry!);
        _entries[index] = updatedEntry;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Eintrag aktualisiert')));
    } else {
      final entry = TimeEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: _selectedDate,
        startTime: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _startTime!.hour,
          _startTime!.minute,
        ),
        endTime: _endTime != null
            ? DateTime(
                _selectedDate.year,
                _selectedDate.month,
                _selectedDate.day,
                _endTime!.hour,
                _endTime!.minute,
              )
            : null,
        description: _descriptionController.text,
      );

      setState(() {
        _entries.add(entry);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Zeit eingetragen')));
    }

    _resetForm();
  }

  void _resetForm() {
    _descriptionController.clear();
    _startTime = null;
    _endTime = null;
    _editingEntry = null;
  }

  void _editEntry(TimeEntry entry) {
    setState(() {
      _editingEntry = entry;
      _selectedDate = entry.date;
      _startTime = TimeOfDay.fromDateTime(entry.startTime);
      _endTime = entry.endTime != null
          ? TimeOfDay.fromDateTime(entry.endTime!)
          : null;
      _descriptionController.text = entry.description;
    });
  }

  Future<void> _selectTime(bool isStart) async {
    final result = await TimeInputDialog.show(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      label: isStart ? 'Startzeit' : 'Endzeit',
    );
    if (result != null) {
      setState(() {
        if (isStart) {
          _startTime = result;
        } else {
          _endTime = result;
        }
      });
    }
  }

  void _deleteEntry(TimeEntry entry) {
    setState(() {
      _entries.remove(entry);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Eintrag gelöscht')));
  }

  void _cancelEdit() {
    _resetForm();
  }

  List<TimeEntry> get _filteredEntries {
    final now = DateTime.now();
    switch (_filterDate) {
      case 'today':
        return _entries
            .where(
              (e) =>
                  e.date.year == now.year &&
                  e.date.month == now.month &&
                  e.date.day == now.day,
            )
            .toList();
      case 'week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return _entries.where((e) => e.date.isAfter(weekAgo)).toList();
      case 'month':
        return _entries
            .where((e) => e.date.month == now.month && e.date.year == now.year)
            .toList();
      default:
        return _entries;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: colors.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Neue Zeit erfassen', style: text.titleLarge),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectDate,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Datum',
                            suffixIcon: Icon(
                              Icons.calendar_today,
                              color: colors.onSurfaceVariant,
                            ),
                            filled: true,
                            fillColor: colors.surface,
                          ),
                          child: Text(
                            DateFormat('dd.MM.yyyy').format(_selectedDate),
                            style: TextStyle(color: colors.onSurface),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(true),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Start',
                            filled: true,
                            fillColor: colors.surface,
                          ),
                          child: Text(
                            _startTime != null
                                ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                                : 'Wählen',
                            style: TextStyle(color: colors.onSurface),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(false),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Ende',
                            filled: true,
                            fillColor: colors.surface,
                          ),
                          child: Text(
                            _endTime != null
                                ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
                                : 'Optional',
                            style: TextStyle(color: colors.onSurface),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  style: TextStyle(color: colors.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Beschreibung',
                    hintText: 'Task beschreiben',
                    hintStyle: TextStyle(color: colors.onSurfaceVariant),
                    prefixIcon: Icon(
                      Icons.description,
                      color: colors.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: colors.surface,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _addEntry,
                        icon: Icon(
                          _editingEntry != null ? Icons.save : Icons.add,
                        ),
                        label: Text(
                          _editingEntry != null ? 'Speichern' : 'Eintragen',
                        ),
                      ),
                    ),
                    if (_editingEntry != null) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _cancelEdit,
                        icon: const Icon(Icons.close),
                        label: const Text('Abbrechen'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text('Einträge', style: text.titleLarge),
            const Spacer(),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'today',
                  label: Text(
                    'Heute',
                    style: TextStyle(color: colors.onSurface),
                  ),
                ),
                ButtonSegment(
                  value: 'week',
                  label: Text(
                    'Woche',
                    style: TextStyle(color: colors.onSurface),
                  ),
                ),
                ButtonSegment(
                  value: 'month',
                  label: Text(
                    'Monat',
                    style: TextStyle(color: colors.onSurface),
                  ),
                ),
              ],
              selected: {_filterDate},
              onSelectionChanged: (s) => setState(() => _filterDate = s.first),
              style: SegmentedButton.styleFrom(
                backgroundColor: colors.surface,
                foregroundColor: colors.onSurface,
                selectedBackgroundColor: colors.primaryContainer,
                selectedForegroundColor: colors.onPrimaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _filteredEntries.isEmpty
              ? Center(
                  child: Text(
                    'Keine Einträge',
                    style: text.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredEntries.length,
                  itemBuilder: (context, index) {
                    final entry = _filteredEntries[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: colors.surfaceContainerHighest,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colors.primaryContainer,
                          child: Icon(
                            Icons.work,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        title: Text(
                          entry.description,
                          style: TextStyle(color: colors.onSurface),
                        ),
                        subtitle: Text(
                          '${DateFormat('HH:mm').format(entry.startTime)} - ${entry.endTime != null ? DateFormat('HH:mm').format(entry.endTime!) : "offen"} (${entry.formattedDuration})',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: colors.primary),
                              onPressed: () => _editEntry(entry),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: colors.error),
                              onPressed: () => _deleteEntry(entry),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}

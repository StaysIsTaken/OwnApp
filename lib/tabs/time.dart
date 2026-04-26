import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:productivity/dataclasses/time_entry.dart';
import 'package:productivity/dataservice/login_service.dart';
import 'package:productivity/dataservice/time_entry_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/provider/settings_provider.dart';
import 'package:provider/provider.dart';

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

  List<TimeEntry> _entries = [];
  bool _isLoading = true;
  String? _error;

  // ── Lifecycle ────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  // ── Data ─────────────────────────────────────
  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final entries = await TimeEntryService.loadAll();
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Fehler beim Laden: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveEntry() async {
    // Default to current time if no start time is selected
    final startToUse = _startTime ?? TimeOfDay.now();

    final startDt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      startToUse.hour,
      startToUse.minute,
    );
    final endDt = _endTime != null
        ? DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            _endTime!.hour,
            _endTime!.minute,
          )
        : null;

    try {
      if (_editingEntry != null) {
        final updated = _editingEntry!.copyWith(
          date: _selectedDate,
          startTime: startDt,
          endTime: endDt,
          clearEndTime: endDt == null,
          description: _descriptionController.text,
        );
        final result = await TimeEntryService.update(updated);
        setState(() {
          final idx = _entries.indexWhere((e) => e.id == result.id);
          if (idx >= 0) _entries[idx] = result;
        });
        _showSnack('Eintrag aktualisiert');
      } else {
        final user = await LoginService.currentUser;
        final entry = TimeEntry(
          id: '',
          userId: user.id,
          date: _selectedDate,
          startTime: startDt,
          endTime: endDt,
          description: _descriptionController.text,
        );
        final result = await TimeEntryService.create(entry);
        setState(() => _entries.add(result));
        _showSnack('Zeit eingetragen');
      }
    } catch (e) {
      _showSnack('Fehler beim Speichern: $e');
    }

    _resetForm();
  }

  Future<void> _deleteEntry(TimeEntry entry) async {
    try {
      await TimeEntryService.delete(entry.id);
      setState(() => _entries.remove(entry));
      _showSnack('Eintrag gelöscht');
    } catch (e) {
      _showSnack('Fehler beim Löschen: $e');
    }
  }

  // ── UI helpers ────────────────────────────────
  void _editEntry(TimeEntry entry) {
    setState(() {
      _editingEntry = entry;
      _selectedDate = entry.date;
      _startTime = TimeOfDay.fromDateTime(entry.startTime);
      _endTime =
          entry.endTime != null ? TimeOfDay.fromDateTime(entry.endTime!) : null;
      _descriptionController.text = entry.description;
    });
  }

  void _resetForm() {
    setState(() {
      _descriptionController.clear();
      _startTime = null;
      _endTime = null;
      _editingEntry = null;
    });
  }

  void _cancelEdit() => _resetForm();

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime(bool isStart) async {
    final initial = isStart ? _startTime : _endTime;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
      helpText: isStart ? 'STARTZEIT WÄHLEN' : 'ENDZEIT WÄHLEN',
      confirmText: 'OK',
      cancelText: 'ABBRECHEN',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: settings.use24hFormat,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
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
            .where(
                (e) => e.date.month == now.month && e.date.year == now.year)
            .toList();
      default:
        return _entries;
    }
  }

  // ── Build ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final settings = Provider.of<SettingsProvider>(context);
    final timeFormat = settings.use24hFormat ? 'HH:mm' : 'hh:mm a';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Entry Form ──────────────────────────
        Card(
          color: colors.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Neue Zeit erfassen', style: text.titleLarge),
                const SizedBox(height: 16),

                // Date picker
                InkWell(
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
                const SizedBox(height: 12),

                // Start / End time
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
                                ? DateFormat(timeFormat).format(DateTime(0, 0, 0, _startTime!.hour, _startTime!.minute))
                                : 'Jetzt',
                            style: TextStyle(
                              color: _startTime != null 
                                ? colors.onSurface 
                                : colors.onSurfaceVariant.withOpacity(0.6)
                            ),
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
                                ? DateFormat(timeFormat).format(DateTime(0, 0, 0, _endTime!.hour, _endTime!.minute))
                                : 'Optional',
                            style: TextStyle(color: colors.onSurface),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description
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

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saveEntry,
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

        // ── List header ─────────────────────────
        Row(
          children: [
            Text('Einträge', style: text.titleLarge),
            const Spacer(),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'today',
                  label: Text('Heute',
                      style: TextStyle(color: colors.onSurface)),
                ),
                ButtonSegment(
                  value: 'week',
                  label: Text('Woche',
                      style: TextStyle(color: colors.onSurface)),
                ),
                ButtonSegment(
                  value: 'month',
                  label: Text('Monat',
                      style: TextStyle(color: colors.onSurface)),
                ),
              ],
              selected: {_filterDate},
              onSelectionChanged: (s) =>
                  setState(() => _filterDate = s.first),
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

        // ── Entry list ───────────────────────────
        Expanded(child: _buildList(colors, text, timeFormat)),
      ],
    );
  }

  Widget _buildList(ColorScheme colors, TextTheme text, String timeFormat) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: colors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 48, color: colors.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(_error!,
                style: text.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant)),
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

    final entries = _filteredEntries;
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'Keine Einträge',
          style: text.bodyMedium
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEntries,
      child: ListView.builder(
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: colors.surfaceContainerHighest,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: colors.primaryContainer,
                child: Icon(
                  Icons.schedule_rounded,
                  color: colors.onPrimaryContainer,
                ),
              ),
              title: Text(
                entry.description,
                style: TextStyle(color: colors.onSurface),
              ),
              subtitle: Text(
                '${DateFormat(timeFormat).format(entry.startTime)} – '
                '${entry.endTime != null ? DateFormat(timeFormat).format(entry.endTime!) : "offen"}'
                '  (${entry.formattedDuration})',
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
    );
  }
}

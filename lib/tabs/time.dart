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
  bool _formExpanded = false;
  DateTime? _customFilterDate;

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

  Future<void> _completeEntry(TimeEntry entry) async {
    try {
      final updated = entry.copyWith(endTime: DateTime.now());
      final result = await TimeEntryService.update(updated);
      setState(() {
        final idx = _entries.indexWhere((e) => e.id == result.id);
        if (idx >= 0) _entries[idx] = result;
      });
      _showSnack('Eintrag beendet');
    } catch (e) {
      _showSnack('Fehler beim Beenden: $e');
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

  Duration _getTotalDuration(List<TimeEntry> entries) {
    Duration total = Duration.zero;
    for (final entry in entries) {
      total += entry.duration;
    }
    return total;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  List<TimeEntry> get _filteredEntries {
    if (_customFilterDate != null) {
      return _entries
          .where(
            (e) =>
                e.date.year == _customFilterDate!.year &&
                e.date.month == _customFilterDate!.month &&
                e.date.day == _customFilterDate!.day,
          )
          .toList();
    }

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
      case 'yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        return _entries
            .where(
              (e) =>
                  e.date.year == yesterday.year &&
                  e.date.month == yesterday.month &&
                  e.date.day == yesterday.day,
            )
            .toList();
      case 'last-thursday':
        int daysBack = (now.weekday - 4 + 7) % 7;
        if (daysBack == 0) daysBack = 7;
        final lastThursday = now.subtract(Duration(days: daysBack));
        return _entries
            .where(
              (e) =>
                  e.date.year == lastThursday.year &&
                  e.date.month == lastThursday.month &&
                  e.date.day == lastThursday.day,
            )
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
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Entry Form (Collapsible on mobile) ──────────────────────────
        if (isMobile)
          _buildMobileForm(colors, text, timeFormat)
        else
          _buildDesktopForm(colors, text, timeFormat),

        if (!isMobile) const SizedBox(height: 24),

        // ── List header ─────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Einträge', style: text.titleLarge),
                  if (_customFilterDate != null)
                    TextButton.icon(
                      onPressed: () => setState(() => _customFilterDate = null),
                      icon: Icon(Icons.clear, color: colors.error),
                      label: Text('Filter löschen', style: TextStyle(color: colors.error)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
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
                        ButtonSegment(
                          value: 'yesterday',
                          label: Text('Gestern',
                              style: TextStyle(color: colors.onSurface)),
                        ),
                        ButtonSegment(
                          value: 'last-thursday',
                          label: Text('Do. letzte Woche',
                              style: TextStyle(color: colors.onSurface)),
                        ),
                      ],
                      selected: {_filterDate},
                      onSelectionChanged: (s) => setState(() {
                        _customFilterDate = null;
                        _filterDate = s.first;
                      }),
                      style: SegmentedButton.styleFrom(
                        backgroundColor: colors.surface,
                        foregroundColor: colors.onSurface,
                        selectedBackgroundColor: colors.primaryContainer,
                        selectedForegroundColor: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _customFilterDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _customFilterDate = picked);
                        }
                      },
                      icon: Icon(Icons.calendar_today, color: colors.primary),
                      label: Text(
                        _customFilterDate != null
                            ? DateFormat('dd.MM.yyyy').format(_customFilterDate!)
                            : 'Datum',
                        style: TextStyle(color: colors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Total Duration ──────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Gesamtzeit',
                  style: text.labelMedium?.copyWith(color: colors.outline),
                ),
                Text(
                  _formatDuration(_getTotalDuration(_filteredEntries)),
                  style: text.headlineSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Entry list ───────────────────────────
        Expanded(child: _buildList(colors, text, timeFormat, isMobile)),
      ],
    );
  }

  Widget _buildMobileForm(ColorScheme colors, TextTheme text, String timeFormat) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        color: colors.surfaceContainerHighest,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text('Neue Zeit erfassen', style: text.titleMedium),
              trailing: Icon(
                _formExpanded ? Icons.expand_less : Icons.expand_more,
                color: colors.onSurface,
              ),
              onTap: () => setState(() => _formExpanded = !_formExpanded),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            if (_formExpanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Text(
                          DateFormat('dd.MM.yyyy').format(_selectedDate),
                          style: TextStyle(color: colors.onSurface),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Start / End time (stacked on mobile)
                    Column(
                      children: [
                        InkWell(
                          onTap: () => _selectTime(true),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Start',
                              filled: true,
                              fillColor: colors.surface,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        const SizedBox(height: 10),
                        Stack(
                          children: [
                            InkWell(
                              onTap: () => _selectTime(false),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Ende',
                                  filled: true,
                                  fillColor: colors.surface,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                child: Text(
                                  _endTime != null
                                      ? DateFormat(timeFormat).format(DateTime(0, 0, 0, _endTime!.hour, _endTime!.minute))
                                      : 'Optional',
                                  style: TextStyle(color: colors.onSurface),
                                ),
                              ),
                            ),
                            if (_endTime != null)
                              Positioned(
                                right: 0,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: IconButton(
                                    icon: Icon(Icons.clear, color: colors.error),
                                    tooltip: 'Endzeit entfernen',
                                    onPressed: () => setState(() => _endTime = null),
                                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                    padding: EdgeInsets.zero,
                                    splashRadius: 20,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),

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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopForm(ColorScheme colors, TextTheme text, String timeFormat) {
    return Card(
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
                  child: Stack(
                    children: [
                      InkWell(
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
                      if (_endTime != null)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: IconButton(
                              icon: Icon(Icons.clear, color: colors.error),
                              tooltip: 'Endzeit entfernen',
                              onPressed: () => setState(() => _endTime = null),
                              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              padding: EdgeInsets.zero,
                              splashRadius: 20,
                            ),
                          ),
                        ),
                    ],
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
    );
  }

  Widget _buildList(ColorScheme colors, TextTheme text, String timeFormat, bool isMobile) {
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
        padding: EdgeInsets.only(
          left: isMobile ? 12 : 0,
          right: isMobile ? 12 : 0,
          bottom: 16,
        ),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${DateFormat(timeFormat).format(entry.startTime)} – '
                '${entry.endTime != null ? DateFormat(timeFormat).format(entry.endTime!) : "offen"}'
                '  (${entry.formattedDuration})',
                style: TextStyle(color: colors.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: SizedBox(
                width: isMobile ? 100 : 140,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (entry.endTime == null && !isMobile)
                      IconButton(
                        icon: Icon(Icons.check_circle, color: colors.secondary),
                        tooltip: 'Beenden',
                        onPressed: () => _completeEntry(entry),
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                      )
                    else if (entry.endTime == null)
                      SizedBox(
                        width: 32,
                        height: 40,
                        child: IconButton(
                          icon: Icon(Icons.check_circle, color: colors.secondary, size: 18),
                          tooltip: 'Beenden',
                          onPressed: () => _completeEntry(entry),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    if (!isMobile)
                      IconButton(
                        icon: Icon(Icons.edit, color: colors.primary),
                        onPressed: () => _editEntry(entry),
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                      )
                    else
                      SizedBox(
                        width: 32,
                        height: 40,
                        child: IconButton(
                          icon: Icon(Icons.edit, color: colors.primary, size: 18),
                          onPressed: () => _editEntry(entry),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    if (!isMobile)
                      IconButton(
                        icon: Icon(Icons.delete, color: colors.error),
                        onPressed: () => _deleteEntry(entry),
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                      )
                    else
                      SizedBox(
                        width: 32,
                        height: 40,
                        child: IconButton(
                          icon: Icon(Icons.delete, color: colors.error, size: 18),
                          onPressed: () => _deleteEntry(entry),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                ),
              ),
              contentPadding: isMobile
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          );
        },
      ),
    );
  }
}

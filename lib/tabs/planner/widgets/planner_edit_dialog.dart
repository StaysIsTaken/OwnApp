import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/dataclasses/planner_recurrence.dart';
import 'package:productivity/dataclasses/User.dart';
import 'package:productivity/dataservice/user_service.dart';
import 'package:productivity/provider/planner_provider.dart';
import 'package:productivity/provider/settings_provider.dart';
import 'package:productivity/provider/user_provider.dart';
import 'package:productivity/widgets/color_picker_dialog.dart';
import 'package:productivity/tabs/planner/manage_planner_types_page.dart';
import 'package:productivity/tabs/planner/widgets/subtask_dialog.dart';

/// Ergebnis des Dialogs (an den Aufrufer zurückgegeben).
class PlannerFormResult {
  final String title;
  final String? description;
  final int typeId;
  final DateTime scheduledAt;
  final DateTime endsAt;
  final int notifyMinBefore;
  final String color;
  final RecurrenceInput? recurrence; // null = einmaliger Termin
  final List<String> participantIds; // leer = nicht geteilt

  PlannerFormResult({
    required this.title,
    required this.description,
    required this.typeId,
    required this.scheduledAt,
    required this.endsAt,
    required this.notifyMinBefore,
    required this.color,
    required this.recurrence,
    required this.participantIds,
  });
}

const _weekdayCodes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
const _weekdayLabels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

class PlannerEditDialog extends StatefulWidget {
  final PlannerEntry? entry;
  final DateTime? initialScheduledAt;
  final DateTime? initialEndsAt;

  /// scope ist nur gesetzt, wenn ein bestehender Serien-Eintrag bearbeitet wird
  /// ('single' | 'all' | 'future'). Sonst null.
  final void Function(PlannerFormResult result, String? scope) onSubmit;

  /// scope wie oben; null bei Einzelterminen.
  final void Function(String? scope)? onDelete;

  const PlannerEditDialog({
    Key? key,
    this.entry,
    this.initialScheduledAt,
    this.initialEndsAt,
    this.onDelete,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<PlannerEditDialog> createState() => _PlannerEditDialogState();
}

class _PlannerEditDialogState extends State<PlannerEditDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _notifyController;
  int? _typeId;
  late DateTime _scheduledAt;
  late DateTime _endsAt;
  late int _notifyMinBefore;
  late String _color;

  // Wiederholung (nur für neue Einträge)
  String? _recurFreq; // null = einmalig
  int _recurInterval = 1;
  final Set<String> _recurWeekdays = {};
  String _recurEndMode = 'never'; // 'never' | 'until' | 'count'
  DateTime? _recurUntil;
  int _recurCount = 10;

  // Teilen mit anderen Usern (nur neue, nicht-wiederkehrende Termine)
  List<User> _users = [];
  final Set<String> _participantIds = {};

  final List<String> _colors = [
    '#3B82F6', '#EF4444', '#10B981', '#F59E0B',
    '#8B5CF6', '#EC4899', '#06B6D4', '#6366F1',
  ];

  bool get _isEditing => widget.entry != null;
  bool get _isSeries => widget.entry?.recurrenceId != null;
  // Unteraufgaben nur an Top-Level-Terminen (keine verschachtelten Children)
  bool get _canHaveSubtasks => _isEditing && widget.entry!.parentId == null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.entry?.description ?? '');
    _typeId = widget.entry?.typeId;
    _scheduledAt =
        widget.entry?.scheduledAt ?? widget.initialScheduledAt ?? DateTime.now();
    _endsAt = widget.entry?.endsAt ??
        widget.initialEndsAt ??
        _scheduledAt.add(const Duration(hours: 1));
    _notifyMinBefore = widget.entry?.notifyMinBefore ?? 10;
    _notifyController =
        TextEditingController(text: _notifyMinBefore.toString());
    _color = widget.entry?.color ?? _colors[0];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PlannerProvider>();
      if (provider.types.isEmpty) provider.loadTypes();
    });

    // Andere User zum Teilen laden (nur bei neuen Terminen relevant)
    if (!_isEditing) _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await UserService.getAllUsers();
      if (!mounted) return;
      final currentId = context.read<UserProvider>().user?.id;
      setState(() {
        _users = users.where((u) => u.id != currentId).toList();
      });
    } catch (_) {
      // Teilen ist optional – Fehler hier ignorieren
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notifyController.dispose();
    super.dispose();
  }

  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  String _formatDate(DateTime dt) => '${dt.day}.${dt.month}.${dt.year}';
  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date != null) {
      setState(() {
        final dur = _endsAt.difference(_scheduledAt);
        _scheduledAt = DateTime(
            date.year, date.month, date.day, _scheduledAt.hour, _scheduledAt.minute);
        _endsAt = _scheduledAt.add(dur);
      });
    }
  }

  Future<TimeOfDay?> _pickTimeOfDay(TimeOfDay initial) {
    final use24h = context.read<SettingsProvider>().use24hFormat;
    return showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: use24h),
        child: child!,
      ),
    );
  }

  Future<void> _pickStartTime() async {
    final t = await _pickTimeOfDay(TimeOfDay.fromDateTime(_scheduledAt));
    if (t != null) {
      setState(() {
        final dur = _endsAt.difference(_scheduledAt);
        _scheduledAt = DateTime(_scheduledAt.year, _scheduledAt.month,
            _scheduledAt.day, t.hour, t.minute);
        _endsAt = _scheduledAt
            .add(dur.inMinutes > 0 ? dur : const Duration(hours: 1));
      });
    }
  }

  Future<void> _pickEndTime() async {
    final t = await _pickTimeOfDay(TimeOfDay.fromDateTime(_endsAt));
    if (t != null) {
      setState(() {
        var end = DateTime(_scheduledAt.year, _scheduledAt.month,
            _scheduledAt.day, t.hour, t.minute);
        if (!end.isAfter(_scheduledAt)) {
          end = end.add(const Duration(days: 1));
        }
        _endsAt = end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final types = context.watch<PlannerProvider>().types;
    final typeIds = types.map((t) => t.id).toList();
    final duration = _endsAt.difference(_scheduledAt);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditing ? 'Eintrag bearbeiten' : 'Neuer Eintrag',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  if (_isEditing && widget.onDelete != null)
                    IconButton(
                      tooltip: 'Löschen',
                      icon: Icon(Icons.delete_outline,
                          color: theme.colorScheme.error),
                      onPressed: _handleDelete,
                    ),
                ],
              ),
              if (_isSeries)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.repeat, size: 16, color: theme.hintColor),
                      const SizedBox(width: 6),
                      Text('Teil einer Serie',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.hintColor)),
                    ],
                  ),
                ),
              if (_sharedWithNames().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.people_outline,
                          size: 16, color: theme.hintColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Geteilt mit ${_sharedWithNames().join(', ')}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.hintColor)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titel',
                  hintText: 'z.B. Team-Meeting',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: typeIds.contains(_typeId) ? _typeId : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Typ', border: OutlineInputBorder()),
                      hint: const Text('Typ wählen'),
                      items: types.map((t) {
                        return DropdownMenuItem(
                          value: t.id,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getColorFromHex(t.color),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(t.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _typeId = value;
                          for (final t in types) {
                            if (t.id == value) _color = t.color;
                          }
                        });
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Typen verwalten',
                    icon: const Icon(Icons.tune),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ManagePlannerTypesPage()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _PickerTile(
                icon: Icons.calendar_today,
                label: 'Datum',
                value: _formatDate(_scheduledAt),
                onTap: _pickDate,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.schedule,
                      label: 'Von',
                      value: _formatTime(_scheduledAt),
                      onTap: _pickStartTime,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.schedule_outlined,
                      label: 'Bis',
                      value: _formatTime(_endsAt),
                      onTap: _pickEndTime,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text('Dauer: ${_formatDuration(duration)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor)),
              ),
              // Wiederholung nur bei neuen Einträgen anbieten
              if (!_isEditing) ...[
                const SizedBox(height: 16),
                _buildRecurrenceSection(theme),
              ],
              // Teilen nur bei neuen, nicht-wiederkehrenden Terminen
              if (!_isEditing && _recurFreq == null && _users.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildShareSection(theme),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _notifyController,
                decoration: const InputDecoration(
                  labelText: 'Benachrichtigung (min vorher)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _notifyMinBefore = int.tryParse(v) ?? 10,
              ),
              const SizedBox(height: 16),
              Text('Farbe', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final color in [
                    ..._colors,
                    if (!_colors.contains(_color)) _color,
                  ])
                    GestureDetector(
                      onTap: () => setState(() => _color = color),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _getColorFromHex(color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color == _color
                                ? theme.colorScheme.onSurface
                                : Colors.transparent,
                            width: color == _color ? 3 : 0,
                          ),
                        ),
                      ),
                    ),
                  // Eigene Farbe wählen
                  GestureDetector(
                    onTap: () async {
                      final picked =
                          await ColorPickerDialog.show(context, _color);
                      if (picked != null) setState(() => _color = picked);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.dividerColor),
                        gradient: const SweepGradient(
                          colors: [
                            Color(0xFFFF0000),
                            Color(0xFFFFFF00),
                            Color(0xFF00FF00),
                            Color(0xFF00FFFF),
                            Color(0xFF0000FF),
                            Color(0xFFFF00FF),
                            Color(0xFFFF0000),
                          ],
                        ),
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
              if (_canHaveSubtasks) ...[
                const SizedBox(height: 20),
                _buildSubtaskSection(theme),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                      onPressed: _handleSave, child: const Text('Speichern')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecurrenceSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: _recurFreq,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Wiederholung',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.repeat),
          ),
          items: const [
            DropdownMenuItem(value: null, child: Text('Nie (einmalig)')),
            DropdownMenuItem(value: 'DAILY', child: Text('Täglich')),
            DropdownMenuItem(value: 'WEEKLY', child: Text('Wöchentlich')),
            DropdownMenuItem(value: 'MONTHLY', child: Text('Monatlich')),
            DropdownMenuItem(value: 'YEARLY', child: Text('Jährlich')),
          ],
          onChanged: (value) {
            setState(() {
              _recurFreq = value;
              if (value == 'WEEKLY' && _recurWeekdays.isEmpty) {
                _recurWeekdays.add(_weekdayCodes[_scheduledAt.weekday - 1]);
              }
            });
          },
        ),
        if (_recurFreq != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Alle '),
              SizedBox(
                width: 56,
                child: TextFormField(
                  initialValue: _recurInterval.toString(),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) =>
                      _recurInterval = (int.tryParse(v) ?? 1).clamp(1, 999),
                ),
              ),
              Text(' ${_intervalUnit(_recurFreq!)}'),
            ],
          ),
          if (_recurFreq == 'WEEKLY') ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: List.generate(7, (i) {
                final code = _weekdayCodes[i];
                final selected = _recurWeekdays.contains(code);
                return FilterChip(
                  label: Text(_weekdayLabels[i]),
                  selected: selected,
                  onSelected: (s) => setState(() {
                    if (s) {
                      _recurWeekdays.add(code);
                    } else {
                      _recurWeekdays.remove(code);
                    }
                  }),
                );
              }),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _recurEndMode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Endet',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'never', child: Text('Nie')),
              DropdownMenuItem(value: 'until', child: Text('Am Datum')),
              DropdownMenuItem(value: 'count', child: Text('Nach Anzahl')),
            ],
            onChanged: (v) => setState(() => _recurEndMode = v ?? 'never'),
          ),
          if (_recurEndMode == 'until') ...[
            const SizedBox(height: 8),
            _PickerTile(
              icon: Icons.event_busy,
              label: 'Enddatum',
              value: _recurUntil == null
                  ? 'wählen'
                  : _formatDate(_recurUntil!),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _recurUntil ??
                      _scheduledAt.add(const Duration(days: 30)),
                  firstDate: _scheduledAt,
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                );
                if (d != null) setState(() => _recurUntil = d);
              },
            ),
          ],
          if (_recurEndMode == 'count') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Nach '),
                SizedBox(
                  width: 64,
                  child: TextFormField(
                    initialValue: _recurCount.toString(),
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) =>
                        _recurCount = (int.tryParse(v) ?? 1).clamp(1, 999),
                  ),
                ),
                const Text(' Terminen'),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildSubtaskSection(ThemeData theme) {
    return Consumer<PlannerProvider>(
      builder: (context, provider, _) {
        final children = provider.getChildEntries(widget.entry!.id);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.checklist, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text('Unteraufgaben', style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('Noch keine Unteraufgaben',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor)),
              ),
            ...children.map(
              (c) {
                final ownTimes = c.scheduledAt != widget.entry!.scheduledAt ||
                    c.endsAt != widget.entry!.endsAt;
                return InkWell(
                  onTap: () => _editSubtask(provider, c),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.subdirectory_arrow_right,
                            size: 16, color: theme.hintColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.title,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              if (ownTimes)
                                Text(
                                  '${_formatClockShort(c.scheduledAt)} – ${_formatClockShort(c.endsAt)}',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: theme.hintColor),
                                ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => provider.deleteChildEntry(c.id),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.close,
                                size: 18, color: theme.colorScheme.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Unteraufgabe hinzufügen'),
                onPressed: () => _addSubtask(provider),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatClockShort(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Future<void> _addSubtask(PlannerProvider provider) async {
    final parent = widget.entry!;
    final typeId = parent.typeId ??
        (provider.types.isNotEmpty ? provider.types.first.id : null);
    if (typeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte zuerst einen Typ anlegen')),
      );
      return;
    }
    final result = await SubtaskDialog.show(context, parent: parent);
    if (result == null) return;
    await provider.createSubtask(
      parentId: parent.id,
      title: result.title,
      typeId: typeId,
      // Keine eigenen Zeiten -> Zeiten des Parent übernehmen
      scheduledAt: result.scheduledAt ?? parent.scheduledAt,
      endsAt: result.endsAt ?? parent.endsAt,
      color: parent.color,
      orderIndex: provider.getChildEntries(parent.id).length,
    );
  }

  Future<void> _editSubtask(PlannerProvider provider, PlannerEntry child) async {
    final parent = widget.entry!;
    final result =
        await SubtaskDialog.show(context, parent: parent, child: child);
    if (result == null) return;
    await provider.updateEntry(
      child.id,
      title: result.title,
      scheduledAt: result.scheduledAt ?? parent.scheduledAt,
      endsAt: result.endsAt ?? parent.endsAt,
    );
  }

  List<String> _sharedWithNames() {
    final entry = widget.entry;
    if (entry == null || entry.participants.length <= 1) return [];
    final me = context.read<UserProvider>().user?.id;
    return entry.participants
        .where((p) => p.userId != me)
        .map((p) => p.username)
        .toList();
  }

  Widget _buildShareSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people_outline, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text('Teilen mit', style: theme.textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _users.map((u) {
            final selected = _participantIds.contains(u.id);
            return FilterChip(
              label: Text(u.username),
              selected: selected,
              onSelected: (s) => setState(() {
                if (s) {
                  _participantIds.add(u.id);
                } else {
                  _participantIds.remove(u.id);
                }
              }),
            );
          }).toList(),
        ),
        if (_participantIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Diese Personen bekommen eine eigene Kopie und werden ebenfalls benachrichtigt.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ),
      ],
    );
  }

  String _intervalUnit(String freq) {
    switch (freq) {
      case 'DAILY':
        return _recurInterval == 1 ? 'Tag' : 'Tage';
      case 'WEEKLY':
        return _recurInterval == 1 ? 'Woche' : 'Wochen';
      case 'MONTHLY':
        return _recurInterval == 1 ? 'Monat' : 'Monate';
      case 'YEARLY':
        return _recurInterval == 1 ? 'Jahr' : 'Jahre';
    }
    return '';
  }

  RecurrenceInput? _buildRecurrence() {
    if (_recurFreq == null) return null;
    return RecurrenceInput(
      freq: _recurFreq!,
      interval: _recurInterval,
      byweekday: _recurFreq == 'WEEKLY' && _recurWeekdays.isNotEmpty
          ? (_weekdayCodes.where(_recurWeekdays.contains).join(','))
          : null,
      bymonthday: _recurFreq == 'MONTHLY' ? _scheduledAt.day : null,
      untilDate: _recurEndMode == 'until' ? _recurUntil : null,
      countN: _recurEndMode == 'count' ? _recurCount : null,
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}min';
    if (h > 0) return '${h}h';
    return '${m}min';
  }

  Future<String?> _pickScope(String action) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('$action – Geltungsbereich'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'single'),
            child: const Text('Nur dieser Termin'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'future'),
            child: const Text('Dieser und folgende'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'all'),
            child: const Text('Alle Termine der Serie'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Titel ist erforderlich')));
      return;
    }
    if (_typeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte einen Typ wählen')));
      return;
    }
    if (!_endsAt.isAfter(_scheduledAt)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Die Endzeit muss nach der Startzeit liegen')));
      return;
    }

    final result = PlannerFormResult(
      title: _titleController.text,
      description:
          _descriptionController.text.isEmpty ? null : _descriptionController.text,
      typeId: _typeId!,
      scheduledAt: _scheduledAt,
      endsAt: _endsAt,
      notifyMinBefore: _notifyMinBefore,
      color: _color,
      recurrence: _isEditing ? null : _buildRecurrence(),
      participantIds:
          (!_isEditing && _recurFreq == null) ? _participantIds.toList() : const [],
    );

    String? scope;
    if (_isSeries) {
      scope = await _pickScope('Ändern');
      if (scope == null) return; // abgebrochen
    }

    if (!mounted) return;
    widget.onSubmit(result, scope);
    Navigator.of(context).pop();
  }

  Future<void> _handleDelete() async {
    if (_isSeries) {
      final scope = await _pickScope('Löschen');
      if (scope == null) return;
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onDelete?.call(scope);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Löschen bestätigen'),
        content: const Text('Möchtest du diesen Eintrag wirklich löschen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed == true) {
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onDelete?.call(null);
    }
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.hintColor)),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

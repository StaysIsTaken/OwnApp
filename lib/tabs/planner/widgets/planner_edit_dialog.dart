import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/provider/planner_provider.dart';
import 'package:productivity/provider/settings_provider.dart';
import 'package:productivity/tabs/planner/manage_planner_types_page.dart';

class PlannerEditDialog extends StatefulWidget {
  final PlannerEntry? entry;
  final DateTime? initialScheduledAt;
  final DateTime? initialEndsAt;
  final VoidCallback? onDelete;
  final Function(
    String title,
    String? description,
    int typeId,
    DateTime scheduledAt,
    DateTime endsAt,
    int notifyMinBefore,
    String color,
    int? parentId,
    int orderIndex,
  )
  onSave;

  const PlannerEditDialog({
    super.key,
    this.entry,
    this.initialScheduledAt,
    this.initialEndsAt,
    this.onDelete,
    required this.onSave,
  });

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
  late int? _parentId;
  late int _orderIndex;

  final List<String> _colors = [
    '#3B82F6', // Blau
    '#EF4444', // Rot
    '#10B981', // Grün
    '#F59E0B', // Orange
    '#8B5CF6', // Lila
    '#EC4899', // Pink
    '#06B6D4', // Cyan
    '#6366F1', // Indigo
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.entry?.description ?? '',
    );
    _typeId = widget.entry?.typeId;
    _scheduledAt =
        widget.entry?.scheduledAt ??
        widget.initialScheduledAt ??
        DateTime.now();
    _endsAt =
        widget.entry?.endsAt ??
        widget.initialEndsAt ??
        _scheduledAt.add(const Duration(hours: 1));
    _notifyMinBefore = widget.entry?.notifyMinBefore ?? 10;
    _notifyController = TextEditingController(
      text: _notifyMinBefore.toString(),
    );
    _color = widget.entry?.color ?? _colors[0];
    _parentId = widget.entry?.parentId;
    _orderIndex = widget.entry?.orderIndex ?? 0;

    // Stammdaten-Typen laden (falls noch nicht geladen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PlannerProvider>();
      if (provider.types.isEmpty) {
        provider.loadTypes();
      }
    });
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
          date.year,
          date.month,
          date.day,
          _scheduledAt.hour,
          _scheduledAt.minute,
        );
        _endsAt = _scheduledAt.add(dur);
      });
    }
  }

  Future<void> _pickStartTime() async {
    final settings = context.read<SettingsProvider>();
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
      use24HourFormat: settings.use24hFormat,
    );
    if (time != null) {
      setState(() {
        final dur = _endsAt.difference(_scheduledAt);
        _scheduledAt = DateTime(
          _scheduledAt.year,
          _scheduledAt.month,
          _scheduledAt.day,
          time.hour,
          time.minute,
        );
        // Ende mitziehen, mindestens jedoch nach dem Start
        _endsAt = _scheduledAt.add(
          dur.inMinutes > 0 ? dur : const Duration(hours: 1),
        );
      });
    }
  }

  Future<void> _pickEndTime() async {
    final settings = context.read<SettingsProvider>();
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endsAt),
      use24HourFormat: settings.use24hFormat,
    );
    if (time != null) {
      setState(() {
        var end = DateTime(
          _scheduledAt.year,
          _scheduledAt.month,
          _scheduledAt.day,
          time.hour,
          time.minute,
        );
        // Endet die Zeit vor dem Start, gilt sie als am nächsten Tag.
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
                      widget.entry == null
                          ? 'Neuer Eintrag'
                          : 'Eintrag bearbeiten',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  if (widget.entry != null && widget.onDelete != null)
                    IconButton(
                      tooltip: 'Löschen',
                      icon: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: _confirmDelete,
                    ),
                ],
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
                  hintText: 'Weitere Details...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              // Typ aus Stammdaten
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: typeIds.contains(_typeId) ? _typeId : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Typ',
                        border: OutlineInputBorder(),
                      ),
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
                            if (t.id == value) {
                              _color = t.color;
                              break;
                            }
                          }
                        });
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Typen verwalten',
                    icon: const Icon(Icons.tune),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ManagePlannerTypesPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Datum
              _PickerTile(
                icon: Icons.calendar_today,
                label: 'Datum',
                value: _formatDate(_scheduledAt),
                onTap: _pickDate,
              ),
              const SizedBox(height: 8),
              // Start- und Endzeit
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
                child: Text(
                  'Dauer: ${_formatDuration(duration)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notifyController,
                decoration: const InputDecoration(
                  labelText: 'Benachrichtigung (min vorher)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) =>
                    _notifyMinBefore = int.tryParse(value) ?? 10,
              ),
              const SizedBox(height: 16),
              Text('Farbe', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _colors.map((color) {
                  final isSelected = color == _color;
                  return GestureDetector(
                    onTap: () => setState(() => _color = color),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _getColorFromHex(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.onSurface
                              : Colors.transparent,
                          width: isSelected ? 3 : 0,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
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
                    onPressed: _save,
                    child: const Text('Speichern'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}min';
    if (h > 0) return '${h}h';
    return '${m}min';
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Löschen bestätigen'),
        content: const Text('Möchtest du diesen Eintrag wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // confirm dialog
              Navigator.of(context).pop(); // edit dialog
              widget.onDelete?.call();
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Titel ist erforderlich')));
      return;
    }
    if (_typeId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bitte einen Typ wählen')));
      return;
    }
    if (!_endsAt.isAfter(_scheduledAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Die Endzeit muss nach der Startzeit liegen'),
        ),
      );
      return;
    }

    widget.onSave(
      _titleController.text,
      _descriptionController.text.isEmpty ? null : _descriptionController.text,
      _typeId!,
      _scheduledAt,
      _endsAt,
      _notifyMinBefore,
      _color,
      _parentId,
      _orderIndex,
    );

    Navigator.of(context).pop();
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
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

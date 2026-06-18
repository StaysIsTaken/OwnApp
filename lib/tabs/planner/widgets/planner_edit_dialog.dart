import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/planner_entry.dart';

class PlannerEditDialog extends StatefulWidget {
  final PlannerEntry? entry;
  final DateTime? initialScheduledAt;
  final int? initialDurationMin;
  final Function(
    String title,
    String? description,
    String type,
    DateTime scheduledAt,
    int durationMin,
    int notifyMinBefore,
    String color,
    int? parentId,
    int orderIndex,
  ) onSave;

  const PlannerEditDialog({
    Key? key,
    this.entry,
    this.initialScheduledAt,
    this.initialDurationMin,
    required this.onSave,
  }) : super(key: key);

  @override
  State<PlannerEditDialog> createState() => _PlannerEditDialogState();
}

class _PlannerEditDialogState extends State<PlannerEditDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String _type;
  late DateTime _scheduledAt;
  late int _durationMin;
  late int _notifyMinBefore;
  late String _color;
  late int? _parentId;
  late int _orderIndex;

  final List<String> _types = ['task', 'meeting', 'reminder', 'deadline'];
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
    _descriptionController =
        TextEditingController(text: widget.entry?.description ?? '');
    _type = widget.entry?.type ?? _types[0];
    _scheduledAt =
        widget.entry?.scheduledAt ?? widget.initialScheduledAt ?? DateTime.now();
    _durationMin =
        widget.entry?.durationMin ?? widget.initialDurationMin ?? 60;
    _notifyMinBefore = widget.entry?.notifyMinBefore ?? 10;
    _color = widget.entry?.color ?? _colors[0];
    _parentId = widget.entry?.parentId;
    _orderIndex = widget.entry?.orderIndex ?? 0;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.entry == null ? 'Neuer Eintrag' : 'Eintrag bearbeiten',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
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
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Typ',
                  border: OutlineInputBorder(),
                ),
                items: _types
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Datum & Zeit'),
                subtitle: Text(
                  '${_scheduledAt.day}.${_scheduledAt.month}.${_scheduledAt.year} ${_scheduledAt.hour.toString().padLeft(2, '0')}:${_scheduledAt.minute.toString().padLeft(2, '0')}',
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _scheduledAt,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
                    );
                    if (time != null) {
                      setState(() {
                        _scheduledAt = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Dauer (min)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(
                        text: _durationMin.toString(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _durationMin = int.tryParse(value) ?? 60;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Benachrichtig (min)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(
                        text: _notifyMinBefore.toString(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _notifyMinBefore = int.tryParse(value) ?? 10;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Farbe',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _colors.map((color) {
                  final isSelected = color == _color;
                  return GestureDetector(
                    onTap: () => setState(() => _color = color),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getColorFromHex(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.transparent,
                          width: isSelected ? 2 : 0,
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
                    onPressed: () {
                      if (_titleController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Titel ist erforderlich')),
                        );
                        return;
                      }

                      widget.onSave(
                        _titleController.text,
                        _descriptionController.text.isEmpty
                            ? null
                            : _descriptionController.text,
                        _type,
                        _scheduledAt,
                        _durationMin,
                        _notifyMinBefore,
                        _color,
                        _parentId,
                        _orderIndex,
                      );

                      Navigator.of(context).pop();
                    },
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
}

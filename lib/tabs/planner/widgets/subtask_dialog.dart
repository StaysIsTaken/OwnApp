import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/provider/settings_provider.dart';

/// Ergebnis des Subtask-Dialogs. scheduledAt/endsAt sind null, wenn keine
/// eigenen Zeiten gewählt wurden -> der Aufrufer nimmt dann die Zeiten des
/// Parent-Eintrags.
class SubtaskResult {
  final String title;
  final DateTime? scheduledAt;
  final DateTime? endsAt;
  SubtaskResult(this.title, this.scheduledAt, this.endsAt);
}

class SubtaskDialog extends StatefulWidget {
  final PlannerEntry parent;
  final PlannerEntry? child; // gesetzt = Bearbeiten

  const SubtaskDialog({Key? key, required this.parent, this.child})
      : super(key: key);

  static Future<SubtaskResult?> show(
    BuildContext context, {
    required PlannerEntry parent,
    PlannerEntry? child,
  }) {
    return showDialog<SubtaskResult>(
      context: context,
      builder: (_) => SubtaskDialog(parent: parent, child: child),
    );
  }

  @override
  State<SubtaskDialog> createState() => _SubtaskDialogState();
}

class _SubtaskDialogState extends State<SubtaskDialog> {
  late TextEditingController _titleController;
  late bool _customTimes;
  late DateTime _scheduledAt;
  late DateTime _endsAt;

  bool get _isEditing => widget.child != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.child?.title ?? '');
    final child = widget.child;
    // Eigene Zeiten standardmäßig an, wenn das Kind von den Parent-Zeiten abweicht
    _customTimes = child != null &&
        (child.scheduledAt != widget.parent.scheduledAt ||
            child.endsAt != widget.parent.endsAt);
    _scheduledAt = child?.scheduledAt ?? widget.parent.scheduledAt;
    _endsAt = child?.endsAt ?? widget.parent.endsAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) => '${dt.day}.${dt.month}.${dt.year}';
  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

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
        _scheduledAt = DateTime(date.year, date.month, date.day,
            _scheduledAt.hour, _scheduledAt.minute);
        _endsAt = _scheduledAt.add(dur);
      });
    }
  }

  Future<void> _pickStart() async {
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

  Future<void> _pickEnd() async {
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
    return AlertDialog(
      title: Text(_isEditing ? 'Unteraufgabe bearbeiten' : 'Neue Unteraufgabe'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Titel',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Eigene Zeiten festlegen'),
              subtitle: Text(
                _customTimes
                    ? 'Eigene Start-/Endzeit'
                    : 'Übernimmt die Zeiten des Haupttermins',
                style: theme.textTheme.bodySmall,
              ),
              value: _customTimes,
              onChanged: (v) => setState(() => _customTimes = v),
            ),
            if (_customTimes) ...[
              const SizedBox(height: 4),
              _tile(theme, Icons.calendar_today, 'Datum',
                  _formatDate(_scheduledAt), _pickDate),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _tile(theme, Icons.schedule, 'Von',
                        _formatTime(_scheduledAt), _pickStart),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _tile(theme, Icons.schedule_outlined, 'Bis',
                        _formatTime(_endsAt), _pickEnd),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Speichern')),
      ],
    );
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Titel ist erforderlich')),
      );
      return;
    }
    if (_customTimes && !_endsAt.isAfter(_scheduledAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Endzeit muss nach der Startzeit liegen')),
      );
      return;
    }
    Navigator.of(context).pop(
      SubtaskResult(
        title,
        _customTimes ? _scheduledAt : null,
        _customTimes ? _endsAt : null,
      ),
    );
  }

  Widget _tile(ThemeData theme, IconData icon, String label, String value,
      VoidCallback onTap) {
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TimeInputDialog extends StatefulWidget {
  final TimeOfDay? initialTime;
  final String label;

  const TimeInputDialog({super.key, this.initialTime, this.label = 'Zeit'});

  static Future<TimeOfDay?> show({
    required BuildContext context,
    TimeOfDay? initialTime,
    String label = 'Zeit',
  }) {
    return showDialog<TimeOfDay>(
      context: context,
      builder: (context) =>
          TimeInputDialog(initialTime: initialTime, label: label),
    );
  }

  @override
  State<TimeInputDialog> createState() => _TimeInputDialogState();
}

class _TimeInputDialogState extends State<TimeInputDialog> {
  final _timeController = TextEditingController();
  TimeOfDay? _selectedTime;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    if (widget.initialTime != null) {
      _selectedTime = widget.initialTime;
      _timeController.text =
          '${widget.initialTime!.hour.toString().padLeft(2, '0')}:${widget.initialTime!.minute.toString().padLeft(2, '0')}';
    }
  }

  bool _validateTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return false;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return false;
    if (hour < 0 || hour > 23) return false;
    if (minute < 0 || minute > 59) return false;

    return true;
  }

  void _onTimeChanged(String value) {
    setState(() {
      _errorText = null;
    });

    if (value.isEmpty) {
      setState(() => _selectedTime = null);
      return;
    }

    if (!_validateTime(value)) {
      setState(() {
        _errorText = 'Ungültige Zeit (HH:MM)';
      });
      return;
    }

    final parts = value.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    setState(() {
      _selectedTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.label, style: TextStyle(color: colors.onSurface)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _timeController,
            keyboardType: const TextInputType.numberWithOptions(signed: false),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
              LengthLimitingTextInputFormatter(5),
            ],
            style: TextStyle(color: colors.onSurface, fontSize: 24),
            decoration: InputDecoration(
              hintText: 'HH:MM',
              hintStyle: TextStyle(color: colors.onSurfaceVariant),
              filled: true,
              fillColor: colors.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              errorText: _errorText,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            textAlign: TextAlign.center,
            onChanged: _onTimeChanged,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Abbrechen',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _selectedTime != null
                    ? () => Navigator.pop(context, _selectedTime)
                    : null,
                child: const Text('Übernehmen'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }
}

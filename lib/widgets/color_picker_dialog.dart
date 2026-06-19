import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Einfacher, eigenständiger Farbwähler (RGB-Slider + Hex-Eingabe).
/// Gibt beim Schließen einen Hex-String '#RRGGBB' zurück (oder null bei Abbruch).
class ColorPickerDialog extends StatefulWidget {
  final String initialColor;
  const ColorPickerDialog({Key? key, required this.initialColor})
      : super(key: key);

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();

  /// Komfort-Helfer zum Öffnen.
  static Future<String?> show(BuildContext context, String initialColor) {
    return showDialog<String>(
      context: context,
      builder: (_) => ColorPickerDialog(initialColor: initialColor),
    );
  }
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late int _r;
  late int _g;
  late int _b;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    final c = _parse(widget.initialColor);
    _r = (c >> 16) & 0xFF;
    _g = (c >> 8) & 0xFF;
    _b = c & 0xFF;
    _hexController = TextEditingController(text: _hex);
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  int _parse(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return int.tryParse(cleaned.length == 6 ? cleaned : '3B82F6', radix: 16) ??
        0x3B82F6;
  }

  String get _hex =>
      '#${_r.toRadixString(16).padLeft(2, '0')}${_g.toRadixString(16).padLeft(2, '0')}${_b.toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();

  Color get _color => Color(0xFF000000 | (_r << 16) | (_g << 8) | _b);

  void _syncHexField() {
    _hexController.value = TextEditingValue(
      text: _hex,
      selection: TextSelection.collapsed(offset: _hex.length),
    );
  }

  void _onHexChanged(String value) {
    final cleaned = value.replaceFirst('#', '');
    if (cleaned.length == 6) {
      final parsed = int.tryParse(cleaned, radix: 16);
      if (parsed != null) {
        setState(() {
          _r = (parsed >> 16) & 0xFF;
          _g = (parsed >> 8) & 0xFF;
          _b = parsed & 0xFF;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Farbe wählen'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vorschau
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _color,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.dividerColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _channel('R', _r, Colors.red, (v) {
              setState(() => _r = v);
              _syncHexField();
            }),
            _channel('G', _g, Colors.green, (v) {
              setState(() => _g = v);
              _syncHexField();
            }),
            _channel('B', _b, Colors.blue, (v) {
              setState(() => _b = v);
              _syncHexField();
            }),
            const SizedBox(height: 12),
            TextField(
              controller: _hexController,
              decoration: const InputDecoration(
                labelText: 'Hex',
                prefixText: '#',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                LengthLimitingTextInputFormatter(7),
                FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F#]')),
              ],
              onChanged: _onHexChanged,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_hex),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }

  Widget _channel(
      String label, int value, Color accent, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(width: 16, child: Text(label)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(activeTrackColor: accent),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 255,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(value.toString(), textAlign: TextAlign.right),
        ),
      ],
    );
  }
}

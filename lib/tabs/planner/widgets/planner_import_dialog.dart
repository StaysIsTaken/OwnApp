import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:productivity/provider/planner_provider.dart';

class PlannerImportDialog extends StatefulWidget {
  const PlannerImportDialog({Key? key}) : super(key: key);

  @override
  State<PlannerImportDialog> createState() => _PlannerImportDialogState();
}

class _PlannerImportDialogState extends State<PlannerImportDialog> {
  final TextEditingController _urlController = TextEditingController();
  int? _typeId;
  bool _loading = false;
  String? _icsContent;
  String? _fileName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PlannerProvider>();
      if (provider.types.isEmpty) provider.loadTypes();
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ics'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    setState(() {
      _icsContent = utf8.decode(bytes, allowMalformed: true);
      _fileName = file.name;
    });
  }

  Future<void> _import() async {
    final url = _urlController.text.trim();
    if (_icsContent == null && url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bitte eine URL angeben oder eine .ics-Datei wählen')),
      );
      return;
    }
    if (_typeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen Typ wählen')),
      );
      return;
    }

    final provider = context.read<PlannerProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _loading = true);
    try {
      final color = provider.types
          .firstWhere((t) => t.id == _typeId,
              orElse: () => provider.types.first)
          .color;
      final result = await provider.importIcs(
        typeId: _typeId!,
        // Datei hat Vorrang vor URL
        url: _icsContent == null ? url : null,
        ics: _icsContent,
        color: color,
      );
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text(
          'Import: ${result['imported'] ?? 0} neu, '
          '${result['updated'] ?? 0} aktualisiert, '
          '${result['series'] ?? 0} Serien',
        ),
      ));
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = context.watch<PlannerProvider>().types;
    final typeIds = types.map((t) => t.id).toList();

    return AlertDialog(
      title: const Text('Kalender importieren'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _urlController,
              enabled: _icsContent == null,
              decoration: const InputDecoration(
                labelText: 'iCal-/iCloud-URL',
                hintText: 'https://… oder webcal://…',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: Text(_fileName ?? '.ics-Datei wählen'),
                    onPressed: _pickFile,
                  ),
                ),
                if (_icsContent != null)
                  IconButton(
                    tooltip: 'Datei entfernen',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _icsContent = null;
                      _fileName = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: typeIds.contains(_typeId) ? _typeId : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Typ für importierte Termine',
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
              onChanged: (v) => setState(() => _typeId = v),
            ),
            const SizedBox(height: 8),
            Text(
              'Einzeltermine und wiederkehrende Serien werden importiert.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _import,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Importieren'),
        ),
      ],
    );
  }
}

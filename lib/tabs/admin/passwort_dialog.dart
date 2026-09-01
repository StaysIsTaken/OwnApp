import 'package:flutter/material.dart';

/// Neues Passwort für ein fremdes Konto.
///
/// Das alte wird nicht abgefragt — wer zurücksetzen können soll, kennt es
/// gerade nicht. Sichtbar, weil man es weitersagen muss.
class PasswortDialog extends StatefulWidget {
  final String name;

  const PasswortDialog({super.key, required this.name});

  @override
  State<PasswortDialog> createState() => _PasswortDialogState();
}

class _PasswortDialogState extends State<PasswortDialog> {
  final _feld = TextEditingController();
  String? _fehler;

  @override
  void dispose() {
    _feld.dispose();
    super.dispose();
  }

  void _uebernehmen() {
    if (_feld.text.length < 8) {
      setState(() => _fehler = 'Mindestens 8 Zeichen.');
      return;
    }
    Navigator.pop(context, _feld.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Passwort für ${widget.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _feld,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Neues Passwort',
              errorText: _fehler,
            ),
            onSubmitted: (_) => _uebernehmen(),
          ),
          const SizedBox(height: 12),
          const Text(
            'Gib es weiter. Das alte gilt ab sofort nicht mehr; eine offene '
            'Sitzung bleibt allerdings bestehen.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _uebernehmen, child: const Text('Setzen')),
      ],
    );
  }
}

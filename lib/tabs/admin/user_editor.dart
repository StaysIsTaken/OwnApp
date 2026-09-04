import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/admin.dart';
import 'package:productivity/dataservice/admin_service.dart';

/// Konto anlegen — mit Rollen von Anfang an.
///
/// Das Passwort setzt die Verwaltung und gibt es weiter; einen Weg, es
/// selbst zu vergeben, gibt es (noch) nicht. Deshalb steht es hier im
/// Klartext, damit man es überhaupt weitersagen kann.
class UserEditor extends StatefulWidget {
  final List<Rolle> rollen;

  const UserEditor({super.key, required this.rollen});

  @override
  State<UserEditor> createState() => _UserEditorState();
}

class _UserEditorState extends State<UserEditor> {
  final _vorname = TextEditingController();
  final _nachname = TextEditingController();
  final _username = TextEditingController();
  final _passwort = TextEditingController();

  final Set<String> _rollen = {};
  bool _standardrolle = true;
  bool _passwortSichtbar = false;
  bool _speichert = false;
  String? _fehler;

  @override
  void initState() {
    super.initState();
    // Vorschlag: erster Buchstabe des Vornamens + Nachname, kleingeschrieben.
    _vorname.addListener(_benutzernameVorschlagen);
    _nachname.addListener(_benutzernameVorschlagen);
  }

  bool _usernameHandisch = false;

  void _benutzernameVorschlagen() {
    if (_usernameHandisch) return;
    final v = _vorname.text.trim().toLowerCase();
    final n = _nachname.text.trim().toLowerCase();
    if (v.isEmpty && n.isEmpty) return;
    final vorschlag = '${v.isEmpty ? "" : v[0]}$n'
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    _username.text = vorschlag;
  }

  @override
  void dispose() {
    _vorname.dispose();
    _nachname.dispose();
    _username.dispose();
    _passwort.dispose();
    super.dispose();
  }

  Future<void> _speichern() async {
    final username = _username.text.trim();
    if (_vorname.text.trim().isEmpty || _nachname.text.trim().isEmpty) {
      setState(() => _fehler = 'Vor- und Nachname fehlen.');
      return;
    }
    if (username.length < 3) {
      setState(() => _fehler = 'Der Benutzername braucht mindestens 3 Zeichen.');
      return;
    }
    if (_passwort.text.length < 8) {
      setState(() => _fehler = 'Das Passwort braucht mindestens 8 Zeichen.');
      return;
    }
    setState(() {
      _speichert = true;
      _fehler = null;
    });
    try {
      await AdminService.benutzerAnlegen(
        username: username,
        vorname: _vorname.text.trim(),
        nachname: _nachname.text.trim(),
        passwort: _passwort.text,
        // Weglassen heißt Standardrolle, `[]` heißt ausdrücklich keine.
        roleIds: _standardrolle ? null : _rollen.toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      final detail = e.response?.data;
      setState(() {
        _speichert = false;
        _fehler = detail is Map && detail['detail'] is String
            ? detail['detail'] as String
            : 'Anlegen hat nicht geklappt.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Neuer Benutzer',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _vorname,
                          decoration: const InputDecoration(labelText: 'Vorname'),
                          textCapitalization: TextCapitalization.words,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _nachname,
                          decoration: const InputDecoration(labelText: 'Nachname'),
                          textCapitalization: TextCapitalization.words,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _username,
                    decoration: const InputDecoration(
                      labelText: 'Benutzername',
                      helperText: 'Damit meldet er sich an.',
                    ),
                    onChanged: (_) => _usernameHandisch = true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwort,
                    obscureText: !_passwortSichtbar,
                    decoration: InputDecoration(
                      labelText: 'Erstes Passwort',
                      helperText: 'Mindestens 8 Zeichen. Gib es weiter — '
                          'es lässt sich später zurücksetzen.',
                      suffixIcon: IconButton(
                        icon: Icon(_passwortSichtbar
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(
                            () => _passwortSichtbar = !_passwortSichtbar),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    value: _standardrolle,
                    onChanged: (an) => setState(() => _standardrolle = an),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Standardrolle vergeben'),
                    subtitle: Text(
                      _standardrolle
                          ? 'Bekommt dieselbe Rolle wie bei einer Registrierung.'
                          : 'Rollen unten selbst auswählen. Keine Auswahl heißt: '
                            'muss erst freigeschaltet werden.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (!_standardrolle)
                    for (final rolle in widget.rollen)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: _rollen.contains(rolle.id),
                        onChanged: (an) => setState(() {
                          if (an == true) {
                            _rollen.add(rolle.id);
                          } else {
                            _rollen.remove(rolle.id);
                          }
                        }),
                        title: Text(rolle.name),
                      ),
                  if (_fehler != null) ...[
                    const SizedBox(height: 16),
                    Text(_fehler!, style: TextStyle(color: scheme.error)),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed:
                            _speichert ? null : () => Navigator.pop(context, false),
                        child: const Text('Abbrechen'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _speichert ? null : _speichern,
                        child: _speichert
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Anlegen'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

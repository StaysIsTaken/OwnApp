import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/admin.dart';
import 'package:productivity/dataservice/admin_service.dart';

/// Rolle anlegen oder ändern: Name, Beschreibung, Häkchen im Rechte-Katalog.
///
/// Die Rechte sind nach Bereich gruppiert und nicht als lange Liste, weil
/// „Vorrat: Sehen / Ändern" die Frage beantwortet, die man tatsächlich hat.
/// Der Katalog kommt vom Server — ein neu programmierter Bereich erscheint
/// hier von selbst.
class RoleEditor extends StatefulWidget {
  final Rolle? rolle;
  final List<Recht> katalog;

  const RoleEditor({super.key, required this.rolle, required this.katalog});

  @override
  State<RoleEditor> createState() => _RoleEditorState();
}

class _RoleEditorState extends State<RoleEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.rolle?.name ?? '');
  late final TextEditingController _key =
      TextEditingController(text: widget.rolle?.key ?? '');
  late final TextEditingController _beschreibung =
      TextEditingController(text: widget.rolle?.beschreibung ?? '');

  late final Set<String> _gewaehlt = {...?widget.rolle?.rechte};
  bool _speichert = false;
  String? _fehler;

  bool get _neu => widget.rolle == null;

  /// Die Adminrolle trägt nur `*`. Daran gibt es mit Häkchen nichts zu
  /// verbessern — also zeigen wir sie und lassen sie in Ruhe.
  bool get _hatStern => _gewaehlt.contains('*');

  Map<String, List<Recht>> get _nachBereich {
    final gruppen = <String, List<Recht>>{};
    for (final r in widget.katalog) {
      gruppen.putIfAbsent(r.bereich, () => []).add(r);
    }
    return gruppen;
  }

  @override
  void dispose() {
    _name.dispose();
    _key.dispose();
    _beschreibung.dispose();
    super.dispose();
  }

  String _schluesselVorschlag(String name) => name
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  Future<void> _speichern() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _fehler = 'Die Rolle braucht einen Namen.');
      return;
    }
    setState(() {
      _speichert = true;
      _fehler = null;
    });
    try {
      if (_neu) {
        final key = _key.text.trim().isEmpty
            ? _schluesselVorschlag(name)
            : _key.text.trim();
        await AdminService.rolleAnlegen(
          key: key,
          name: name,
          beschreibung: _beschreibung.text.trim().isEmpty
              ? null
              : _beschreibung.text.trim(),
          rechte: _gewaehlt.toList(),
        );
      } else {
        await AdminService.rolleAendern(
          widget.rolle!.id,
          name: name,
          beschreibung: _beschreibung.text.trim(),
          rechte: _gewaehlt.toList(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      final detail = e.response?.data;
      setState(() {
        _speichert = false;
        _fehler = detail is Map && detail['detail'] is String
            ? detail['detail'] as String
            : 'Speichern hat nicht geklappt.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final einfuegen = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: einfuegen),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
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
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _neu ? 'Neue Rolle' : 'Rolle bearbeiten',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (widget.rolle?.istSystem == true)
                    Tooltip(
                      message: 'Systemrolle – lässt sich nicht löschen',
                      child: Icon(Icons.lock_outline,
                          size: 18, color: scheme.outline),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'z. B. Gast',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_neu) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _key,
                      decoration: InputDecoration(
                        labelText: 'Schlüssel (technisch)',
                        hintText: _schluesselVorschlag(_name.text),
                        helperText: 'Bleibt gleich, auch wenn der Name sich '
                            'ändert. Leer lassen genügt.',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _beschreibung,
                    decoration: const InputDecoration(
                      labelText: 'Beschreibung (optional)',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  if (_hatStern)
                    Card(
                      color: scheme.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.all_inclusive,
                                color: scheme.onSecondaryContainer),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Diese Rolle hat alle Rechte — auch solche, '
                                'die es heute noch gar nicht gibt. Deshalb '
                                'gibt es hier nichts anzuhaken.',
                                style: TextStyle(
                                    color: scheme.onSecondaryContainer,
                                    fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._rechteBereiche(scheme),
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
                        onPressed: _speichert
                            ? null
                            : () => Navigator.pop(context, false),
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
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Speichern'),
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

  List<Widget> _rechteBereiche(ColorScheme scheme) {
    final gruppen = _nachBereich;
    return [
      Row(
        children: [
          Text('Rechte', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          Text('${_gewaehlt.length} gewählt',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      const SizedBox(height: 8),
      for (final bereich in gruppen.keys)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(bereich,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    TextButton(
                      onPressed: () => _bereichUmschalten(gruppen[bereich]!),
                      child: Text(
                        _bereichVoll(gruppen[bereich]!) ? 'Keins' : 'Alle',
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final recht in gruppen[bereich]!)
                      FilterChip(
                        label: Text(recht.aktionLesbar),
                        tooltip: recht.beschreibung,
                        selected: _gewaehlt.contains(recht.key),
                        onSelected: (an) => setState(() {
                          if (an) {
                            _gewaehlt.add(recht.key);
                            // Ändern ohne Sehen ergibt keine Oberfläche, die
                            // jemand bedienen kann – das Lesen kommt mit.
                            final lesen = '${recht.key.split(':').first}:read';
                            if (recht.aktion == 'write' &&
                                widget.katalog.any((r) => r.key == lesen)) {
                              _gewaehlt.add(lesen);
                            }
                          } else {
                            _gewaehlt.remove(recht.key);
                            // Umgekehrt: ohne Sehen ist Ändern sinnlos.
                            if (recht.aktion == 'read') {
                              _gewaehlt.remove(
                                  '${recht.key.split(':').first}:write');
                            }
                          }
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ];
  }

  bool _bereichVoll(List<Recht> rechte) =>
      rechte.every((r) => _gewaehlt.contains(r.key));

  void _bereichUmschalten(List<Recht> rechte) {
    setState(() {
      if (_bereichVoll(rechte)) {
        _gewaehlt.removeAll(rechte.map((r) => r.key));
      } else {
        _gewaehlt.addAll(rechte.map((r) => r.key));
      }
    });
  }
}

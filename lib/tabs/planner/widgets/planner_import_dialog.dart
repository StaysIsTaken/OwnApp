import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:productivity/dataclasses/kalender.dart';
import 'package:productivity/provider/planner_provider.dart';

/// Eine .ics-Datei oder -Adresse einlesen — **in einen bestimmten Kalender**.
///
/// Das ist der Unterschied zu vorher: der Dialog fragte nach Quelle und
/// Termintyp und schwieg darüber, wo die Termine landen. Sie fielen in den
/// Standardkalender, und damit war die Trennung nach Kalendern für den
/// Import wirkungslos — bei einer Datei mit dreihundert Terminen merkt man
/// das erst hinterher, und dann ist es Handarbeit.
///
/// Deshalb steht die Kalenderliste **oben** und nicht als letztes Feld:
/// „wohin" ist die Frage, die man vor dem Einlesen beantwortet haben will.
/// Sie zeigt nur, wohin man schreiben darf — den eigenen und die Kalender
/// des Haushalts. Ein fremder freigegebener Kalender steht nicht dabei:
/// eine Freigabe öffnet ihn zum Lesen.
class PlannerImportDialog extends StatefulWidget {
  const PlannerImportDialog({super.key});

  @override
  State<PlannerImportDialog> createState() => _PlannerImportDialogState();
}

class _PlannerImportDialogState extends State<PlannerImportDialog> {
  final TextEditingController _urlController = TextEditingController();
  int? _typeId;
  int? _kalenderId;
  bool _loading = false;
  String? _icsContent;
  String? _fileName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<PlannerProvider>();
      if (provider.types.isEmpty) await provider.loadTypes();
      if (provider.kalender.isEmpty) await provider.loadKalender();
      if (!mounted) return;
      setState(() => _kalenderId ??= _vorgabe(provider.kalender)?.id);
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  /// Wohin ohne eigene Wahl: der Standardkalender.
  ///
  /// Der eine, den jeder hat — genau der, in dem vorher stillschweigend
  /// alles landete. Die Vorgabe ändert sich also nicht, sie steht jetzt
  /// nur da.
  static Kalender? _vorgabe(List<Kalender> kalender) {
    final beschreibbar = kalender.where((k) => k.darfSchreiben);
    if (beschreibbar.isEmpty) return null;
    return beschreibbar.firstWhere((k) => k.istStandard,
        orElse: () => beschreibbar.first);
  }

  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  Future<void> _pickFile() async {
    // file_picker 12: kein FilePicker.platform und kein FilePickerResult mehr.
    // pickFile liefert direkt eine Datei oder null, und die Bytes holt man
    // ueber readAsBytes statt ueber das inzwischen verworfene withData.
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['ics'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
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
    final ziel = _gewaehlter(provider.kalender);
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
        calendarId: _kalenderId,
        color: color,
      );
      navigator.pop();
      // Der Kalender steht in der Meldung: ohne ihn muss man erst
      // nachsehen, ob es der richtige war.
      final wohin = ziel == null ? 'Import' : _in(ziel);
      messenger.showSnackBar(SnackBar(
        content: Text(
          '$wohin: ${result['imported'] ?? 0} neu, '
          '${result['updated'] ?? 0} aktualisiert, '
          '${result['series'] ?? 0} Serien',
        ),
      ));
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  /// „In ‚Familie‘“ — als eigene Zeile, weil ein
  /// Anführungszeichen in einer Zeichenkette mit Einsetzungen schnell
  /// zur Klammerjagd wird.
  static String _in(Kalender k) => 'In „${k.name}“';

  Kalender? _gewaehlter(List<Kalender> kalender) {
    for (final k in kalender) {
      if (k.id == _kalenderId) return k;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final planer = context.watch<PlannerProvider>();
    final types = planer.types;
    final typeIds = types.map((t) => t.id).toList();
    final ziele = planer.kalender.where((k) => k.darfSchreiben).toList();
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Kalender importieren'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ueberschrift('WOHIN'),
              if (ziele.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Es sind noch keine Kalender geladen. Ohne Angabe '
                    'landen die Termine in deinem Standardkalender.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                )
              else
                // Eine Liste und kein Klappfeld: es geht um die Frage, die
                // man sich vor dem Einlesen stellen soll, und ein
                // zugeklapptes Feld beantwortet sie stillschweigend selbst.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: RadioGroup<int>(
                    groupValue: _kalenderId,
                    // RadioGroup verlangt einen Rueckruf; waehrend des
                    // Einlesens tut er nichts, statt null zu sein.
                    onChanged: (v) {
                      if (_loading) return;
                      setState(() => _kalenderId = v);
                    },
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final k in ziele)
                          RadioListTile<int>(
                            value: k.id,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            secondary: CircleAvatar(
                              backgroundColor: _getColorFromHex(k.color),
                              radius: 12,
                            ),
                            title: Text(k.name),
                            subtitle: Text(_untertitel(k)),
                          ),
                      ],
                    ),
                  ),
                ),
              const Divider(height: 28),
              _ueberschrift('WORAUS'),
              const SizedBox(height: 8),
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

  /// Was den Kalender unterscheidbar macht.
  ///
  /// „Mein Kalender" heißt bei jedem so, und im Haushalt stehen mehrere
  /// davon nebeneinander — der Besitzer beziehungsweise der Haushalt ist
  /// hier die eigentliche Angabe, nicht der Name.
  String _untertitel(Kalender k) {
    final teile = <String>[
      if (k.istHaushaltskalender)
        'gemeinsam · ${k.ownerName}'
      else if (k.istStandard)
        'dein Standardkalender',
      if (k.istAbonniert) 'abonniert',
      '${k.anzahlTermine} ${k.anzahlTermine == 1 ? "Termin" : "Termine"}',
    ];
    return teile.where((t) => t.isNotEmpty).join(' · ');
  }

  Widget _ueberschrift(String titel) => Text(
        titel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
}

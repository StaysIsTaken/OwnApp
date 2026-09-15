import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:productivity/dataclasses/finanzen.dart';
import 'package:productivity/dataservice/finanz_rechnung.dart';

/// Was der Dialog zurückgibt.
class Serieneingabe {
  final int kasseId;
  final String titel;
  final DateTime start;

  /// Schon mit Vorzeichen. Beim Ändern einer bestehenden Serie wird er
  /// nicht mitgeschickt — der Betrag gehört in die Staffel.
  final int cents;

  final String freq;
  final int intervall;
  final String? wochentage;
  final int? monatstag;
  final DateTime? ende;
  final int? kategorieId;
  final String? notiz;

  const Serieneingabe({
    required this.kasseId,
    required this.titel,
    required this.start,
    required this.cents,
    required this.freq,
    required this.intervall,
    this.wochentage,
    this.monatstag,
    this.ende,
    this.kategorieId,
    this.notiz,
  });
}

/// Einen Dauerauftrag anlegen oder seine Regel ändern.
///
/// **Der Betrag steht nur beim Anlegen hier.** Danach gehört er in die
/// Staffel: „ab April 94,50" ist eine neue Stufe und keine Änderung der
/// Regel. Böte der Dialog ihn weiter an, schriebe man den Januar
/// rückwirkend um, ohne es zu merken — genau das soll der Entwurf
/// verhindern.
class SerieDialog extends StatefulWidget {
  final List<Kasse> kassen;
  final List<Finanzkategorie> kategorien;
  final Dauerauftrag? vorhanden;

  const SerieDialog({
    super.key,
    required this.kassen,
    required this.kategorien,
    this.vorhanden,
  });

  static Future<Serieneingabe?> zeige(
    BuildContext context, {
    required List<Kasse> kassen,
    required List<Finanzkategorie> kategorien,
    Dauerauftrag? vorhanden,
  }) =>
      showDialog<Serieneingabe>(
        context: context,
        builder: (_) => SerieDialog(
          kassen: kassen,
          kategorien: kategorien,
          vorhanden: vorhanden,
        ),
      );

  @override
  State<SerieDialog> createState() => _SerieDialogState();
}

class _SerieDialogState extends State<SerieDialog> {
  late final TextEditingController _titel;
  late final TextEditingController _betrag;

  late bool _ausgabe;
  late String _freq;
  late int _intervall;
  late DateTime _start;
  DateTime? _ende;
  int? _monatstag;
  int? _kasseId;
  int? _kategorieId;
  final Set<String> _tage = {};
  String? _fehler;

  bool get _neu => widget.vorhanden == null;

  @override
  void initState() {
    super.initState();
    final v = widget.vorhanden;

    _titel = TextEditingController(text: v?.titel ?? '');
    _betrag = TextEditingController();
    _ausgabe = v == null || v.istAusgabe;
    _freq = v?.freq ?? 'MONTHLY';
    _intervall = v?.intervall ?? 1;
    _start = v?.start ?? DateTime.now();
    _ende = v?.ende;
    _monatstag = v?.monatstag;
    _kasseId = v?.kasseId ??
        (widget.kassen.isNotEmpty ? widget.kassen.first.id : null);
    _kategorieId = v?.kategorieId;
    if (v?.wochentage != null) {
      _tage.addAll(v!.wochentage!.split(',').map((t) => t.trim().toUpperCase()));
    }
  }

  @override
  void dispose() {
    _titel.dispose();
    _betrag.dispose();
    super.dispose();
  }

  List<Finanzkategorie> get _passende => widget.kategorien
      .where((k) => k.passtZu(ausgabe: _ausgabe))
      .toList();

  Future<void> _datum({required bool start}) async {
    final gewaehlt = await showDatePicker(
      context: context,
      initialDate: start ? _start : (_ende ?? _start),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: start ? 'Ab wann?' : 'Bis wann?',
    );
    if (gewaehlt == null) return;
    setState(() {
      if (start) {
        _start = gewaehlt;
      } else {
        _ende = gewaehlt;
      }
    });
  }

  void _speichern() {
    var cents = 0;
    if (_neu) {
      final gelesen = Finanzrechnung.cents(_betrag.text);
      if (gelesen == null || gelesen == 0) {
        setState(() => _fehler = 'Trag einen Betrag ein, zum Beispiel 89,00.');
        return;
      }
      cents = _ausgabe ? -gelesen.abs() : gelesen.abs();
    }
    if (_kasseId == null) {
      setState(() => _fehler = 'Ohne Kasse geht es nicht.');
      return;
    }
    final titel = _titel.text.trim();
    if (titel.isEmpty) {
      setState(() => _fehler = 'Wie soll der Dauerauftrag heissen?');
      return;
    }
    if (_freq == 'WEEKLY' && _tage.isEmpty) {
      setState(() => _fehler = 'Wähl mindestens einen Wochentag.');
      return;
    }
    if (_ende != null && _ende!.isBefore(_start)) {
      setState(() => _fehler = 'Das Ende liegt vor dem Anfang.');
      return;
    }

    Navigator.pop(
      context,
      Serieneingabe(
        kasseId: _kasseId!,
        titel: titel,
        start: _start,
        cents: cents,
        freq: _freq,
        intervall: _intervall,
        wochentage: _freq == 'WEEKLY' ? _tage.join(',') : null,
        monatstag: (_freq == 'MONTHLY' || _freq == 'YEARLY')
            ? (_monatstag ?? _start.day)
            : null,
        ende: _ende,
        kategorieId: _kategorieId,
        notiz: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(_neu ? 'Neuer Dauerauftrag' : 'Regel ändern'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titel,
              autofocus: _neu,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Wofür?',
                hintText: 'Miete, Strom, Gehalt …',
              ),
            ),
            const SizedBox(height: 12),
            if (_neu) ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Ausgabe')),
                  ButtonSegment(value: false, label: Text('Einnahme')),
                ],
                selected: {_ausgabe},
                onSelectionChanged: (s) => setState(() {
                  _ausgabe = s.first;
                  if (!_passende.any((k) => k.id == _kategorieId)) {
                    _kategorieId = null;
                  }
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _betrag,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Betrag',
                  suffixText: '€',
                  helperText: 'Änderungen später als Stufe „ab Stichtag".',
                ),
              ),
              const SizedBox(height: 12),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Der Betrag wird hier nicht geändert — er gehört in die '
                  'Staffel. „Ab April 94,50" ist eine neue Stufe; so bleibt '
                  'der Januar bei seinem alten Wert.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
            DropdownButtonFormField<String>(
              initialValue: _freq,
              decoration: const InputDecoration(labelText: 'Wie oft?'),
              items: const [
                DropdownMenuItem(value: 'MONTHLY', child: Text('Monatlich')),
                DropdownMenuItem(value: 'WEEKLY', child: Text('Wöchentlich')),
                DropdownMenuItem(value: 'YEARLY', child: Text('Jährlich')),
                DropdownMenuItem(value: 'DAILY', child: Text('Täglich')),
              ],
              onChanged: (v) => setState(() => _freq = v ?? 'MONTHLY'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Alle'),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _intervall.toDouble(),
                    min: 1,
                    max: 12,
                    divisions: 11,
                    label: '$_intervall',
                    onChanged: (v) => setState(() => _intervall = v.round()),
                  ),
                ),
                Text(_einheit()),
              ],
            ),
            if (_freq == 'WEEKLY') ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final e in const {
                    'MO': 'Mo', 'TU': 'Di', 'WE': 'Mi', 'TH': 'Do',
                    'FR': 'Fr', 'SA': 'Sa', 'SU': 'So',
                  }.entries)
                    FilterChip(
                      label: Text(e.value),
                      selected: _tage.contains(e.key),
                      onSelected: (an) => setState(() {
                        an ? _tage.add(e.key) : _tage.remove(e.key);
                      }),
                    ),
                ],
              ),
            ],
            if (_freq == 'MONTHLY' || _freq == 'YEARLY') ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _monatstag ?? _start.day,
                decoration: const InputDecoration(labelText: 'An welchem Tag?'),
                items: [
                  for (var t = 1; t <= 31; t++)
                    DropdownMenuItem(
                      value: t,
                      // Ehrlich beim 31.: der Server kürzt auf den
                      // Monatsletzten, damit der Februar nicht ausfällt.
                      child: Text(t == 31 ? 'am Monatsletzten' : 'am $t.'),
                    ),
                ],
                onChanged: (v) => setState(() => _monatstag = v),
              ),
            ],
            const SizedBox(height: 12),
            if (widget.kassen.length > 1) ...[
              DropdownButtonFormField<int>(
                initialValue: _kasseId,
                decoration: const InputDecoration(labelText: 'Kasse'),
                items: [
                  for (final k in widget.kassen)
                    DropdownMenuItem(value: k.id, child: Text(k.name)),
                ],
                onChanged: (v) => setState(() => _kasseId = v),
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<int?>(
              initialValue: _kategorieId,
              decoration: const InputDecoration(labelText: 'Kategorie'),
              items: [
                const DropdownMenuItem(value: null, child: Text('— keine —')),
                for (final k in _passende)
                  DropdownMenuItem(value: k.id, child: Text(k.name)),
              ],
              onChanged: (v) => setState(() => _kategorieId = v),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _datum(start: true),
              icon: const Icon(Icons.event_rounded),
              label: Text('Ab ${Finanzrechnung.alsDatum(_start)}'),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _datum(start: false),
                    icon: const Icon(Icons.event_busy_rounded),
                    label: Text(_ende == null
                        ? 'Kein Ende'
                        : 'Bis ${Finanzrechnung.alsDatum(_ende!)}'),
                  ),
                ),
                if (_ende != null)
                  IconButton(
                    tooltip: 'Ende entfernen',
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () => setState(() => _ende = null),
                  ),
              ],
            ),
            if (_fehler != null) ...[
              const SizedBox(height: 12),
              Text(_fehler!, style: TextStyle(color: colors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _speichern,
          child: Text(_neu ? 'Anlegen' : 'Speichern'),
        ),
      ],
    );
  }

  String _einheit() {
    switch (_freq) {
      case 'DAILY':
        return _intervall == 1 ? 'Tag' : 'Tage';
      case 'WEEKLY':
        return _intervall == 1 ? 'Woche' : 'Wochen';
      case 'YEARLY':
        return _intervall == 1 ? 'Jahr' : 'Jahre';
      default:
        return _intervall == 1 ? 'Monat' : 'Monate';
    }
  }
}

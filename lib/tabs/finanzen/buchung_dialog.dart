import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:productivity/dataclasses/finanzen.dart';
import 'package:productivity/dataservice/finanz_rechnung.dart';

/// Was der Dialog zurückgibt, wenn jemand auf „Buchen" tippt.
class Buchungseingabe {
  final int kasseId;
  final DateTime tag;

  /// Schon mit Vorzeichen — negativ ist eine Ausgabe.
  final int cents;

  final String titel;
  final int? kategorieId;
  final String? notiz;

  const Buchungseingabe({
    required this.kasseId,
    required this.tag,
    required this.cents,
    required this.titel,
    this.kategorieId,
    this.notiz,
  });
}

/// Eine Buchung anlegen oder ändern.
///
/// Der Betrag wird **ohne Vorzeichen** getippt; die Richtung ist ein
/// Schalter. Ein Minuszeichen im Eingabefeld wäre der sicherste Weg,
/// versehentlich eine Einnahme zu buchen — man sieht es nicht, wenn es
/// fehlt.
class BuchungDialog extends StatefulWidget {
  final List<Kasse> kassen;
  final List<Finanzkategorie> kategorien;

  /// Gesetzt, wenn eine bestehende Buchung geändert wird.
  final Buchung? vorhanden;

  /// Womit der Dialog aufgeht, wenn nichts vorgegeben ist.
  final int? kasseVorgabe;

  /// Vorbelegter Betrag in Cent, ohne Vorzeichen gelesen.
  final int? betragVorgabe;
  final String? titelVorgabe;

  /// Eine Zeile über den Feldern, die sagt, woher die Zahl kommt.
  ///
  /// Der Einkauf füllt das mit „Geschätzt aus 7 Preisen. 2 Posten ohne
  /// Preis: …". Ohne diesen Satz sähe der Betrag aus wie eine Tatsache —
  /// und wer ihn ungeprüft bucht, füllt sein Kassenbuch mit plausibel
  /// aussehender Erfindung.
  final String? hinweis;

  const BuchungDialog({
    super.key,
    required this.kassen,
    required this.kategorien,
    this.vorhanden,
    this.kasseVorgabe,
    this.betragVorgabe,
    this.titelVorgabe,
    this.hinweis,
  });

  static Future<Buchungseingabe?> zeige(
    BuildContext context, {
    required List<Kasse> kassen,
    required List<Finanzkategorie> kategorien,
    Buchung? vorhanden,
    int? kasseVorgabe,
    int? betragVorgabe,
    String? titelVorgabe,
    String? hinweis,
  }) =>
      showDialog<Buchungseingabe>(
        context: context,
        builder: (_) => BuchungDialog(
          kassen: kassen,
          kategorien: kategorien,
          vorhanden: vorhanden,
          kasseVorgabe: kasseVorgabe,
          betragVorgabe: betragVorgabe,
          titelVorgabe: titelVorgabe,
          hinweis: hinweis,
        ),
      );

  @override
  State<BuchungDialog> createState() => _BuchungDialogState();
}

class _BuchungDialogState extends State<BuchungDialog> {
  late final TextEditingController _betrag;
  late final TextEditingController _titel;
  late final TextEditingController _notiz;

  late bool _ausgabe;
  late DateTime _tag;
  int? _kasseId;
  int? _kategorieId;
  String? _fehler;

  @override
  void initState() {
    super.initState();
    final v = widget.vorhanden;

    _ausgabe = v == null || v.istAusgabe;
    _tag = v?.tag ?? DateTime.now();
    _kasseId = v?.kasseId ??
        widget.kasseVorgabe ??
        (widget.kassen.isNotEmpty ? widget.kassen.first.id : null);
    _kategorieId = v?.kategorieId;

    final vorgabe = v?.cents ?? widget.betragVorgabe;
    _betrag = TextEditingController(
      text: vorgabe == null || vorgabe == 0
          ? ''
          : Finanzrechnung.nurBetrag(vorgabe).replaceAll(' €', ''),
    );
    _titel = TextEditingController(text: v?.titel ?? widget.titelVorgabe ?? '');
    _notiz = TextEditingController(text: v?.notiz ?? '');
  }

  @override
  void dispose() {
    _betrag.dispose();
    _titel.dispose();
    _notiz.dispose();
    super.dispose();
  }

  /// Nur die Kategorien, die zur gewählten Richtung passen.
  ///
  /// „Gehalt" unter den Ausgaben anzubieten hilft niemandem — und eine
  /// falsch einsortierte Buchung fällt erst in der Auswertung auf.
  List<Finanzkategorie> get _passende =>
      widget.kategorien.where((k) => k.passtZu(ausgabe: _ausgabe)).toList();

  void _richtung(bool ausgabe) {
    setState(() {
      _ausgabe = ausgabe;
      // Passt die gewählte Kategorie nicht mehr, fällt sie weg statt
      // unsichtbar stehenzubleiben.
      if (!_passende.any((k) => k.id == _kategorieId)) _kategorieId = null;
    });
  }

  Future<void> _datumWaehlen() async {
    final gewaehlt = await showDatePicker(
      context: context,
      initialDate: _tag,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Wann war das?',
    );
    if (gewaehlt != null) setState(() => _tag = gewaehlt);
  }

  void _buchen() {
    final cents = Finanzrechnung.cents(_betrag.text);
    if (cents == null || cents == 0) {
      setState(() => _fehler = 'Trag einen Betrag ein, zum Beispiel 12,50.');
      return;
    }
    if (_kasseId == null) {
      setState(() => _fehler = 'Ohne Kasse geht es nicht.');
      return;
    }
    final titel = _titel.text.trim();
    if (titel.isEmpty) {
      setState(() => _fehler = 'Wofür war das? Ein Stichwort genügt.');
      return;
    }

    Navigator.pop(
      context,
      Buchungseingabe(
        kasseId: _kasseId!,
        tag: _tag,
        // Der Betrag wird ohne Vorzeichen getippt; hier bekommt er es.
        cents: _ausgabe ? -cents.abs() : cents.abs(),
        titel: titel,
        kategorieId: _kategorieId,
        notiz: _notiz.text.trim().isEmpty ? null : _notiz.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.vorhanden == null ? 'Neue Buchung' : 'Buchung ändern'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.hinweis != null) ...[
              Text(
                widget.hinweis!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
            ],
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Ausgabe'),
                  icon: Icon(Icons.south_rounded),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Einnahme'),
                  icon: Icon(Icons.north_rounded),
                ),
              ],
              selected: {_ausgabe},
              onSelectionChanged: (s) => _richtung(s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _betrag,
              autofocus: widget.vorhanden == null,
              // Komma UND Punkt erlaubt: der eine tippt das eine, der
              // andere kopiert das andere aus der Banking-App.
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'Betrag',
                suffixText: '€',
                prefixIcon: Icon(
                  _ausgabe ? Icons.remove_rounded : Icons.add_rounded,
                  color: _ausgabe ? colors.error : Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titel,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Wofür?',
                hintText: 'Edeka, Miete, Gehalt …',
              ),
            ),
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
              onPressed: _datumWaehlen,
              icon: const Icon(Icons.event_rounded),
              label: Text(Finanzrechnung.alsDatum(_tag)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notiz,
              decoration: const InputDecoration(labelText: 'Notiz (optional)'),
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
          onPressed: _buchen,
          child: Text(widget.vorhanden == null ? 'Buchen' : 'Speichern'),
        ),
      ],
    );
  }
}

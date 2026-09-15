import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:productivity/dataclasses/finanzen.dart';
import 'package:productivity/dataservice/finanz_rechnung.dart';

class Stufeneingabe {
  final DateTime gueltigAb;
  final int cents;
  final String? notiz;

  const Stufeneingabe({
    required this.gueltigAb,
    required this.cents,
    this.notiz,
  });
}

/// „Ab April kostet der Abschlag 94,50."
///
/// Der Kern des ganzen Entwurfs, in einem Dialog: der Betrag bekommt
/// einen Stichtag, statt den alten zu überschreiben. Der Januar bleibt
/// bei 89 €, und die Frage „was habe ich letztes Jahr für Strom gezahlt"
/// beantwortet sich weiter richtig.
class StufeDialog extends StatefulWidget {
  final Dauerauftrag serie;

  const StufeDialog({super.key, required this.serie});

  static Future<Stufeneingabe?> zeige(
    BuildContext context, {
    required Dauerauftrag serie,
  }) =>
      showDialog<Stufeneingabe>(
        context: context,
        builder: (_) => StufeDialog(serie: serie),
      );

  @override
  State<StufeDialog> createState() => _StufeDialogState();
}

class _StufeDialogState extends State<StufeDialog> {
  final _betrag = TextEditingController();
  final _notiz = TextEditingController();

  /// Vorbelegt auf den **nächsten Monatsersten**.
  ///
  /// Ein Abschlag ändert sich zum Monatswechsel, nicht mitten im Monat —
  /// und das heutige Datum wäre hier fast immer die falsche Vorgabe.
  late DateTime _ab = Finanzrechnung.monatVersetzt(DateTime.now(), 1);

  String? _fehler;

  @override
  void dispose() {
    _betrag.dispose();
    _notiz.dispose();
    super.dispose();
  }

  Future<void> _datum() async {
    final gewaehlt = await showDatePicker(
      context: context,
      initialDate: _ab,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Ab wann gilt der neue Betrag?',
    );
    if (gewaehlt != null) setState(() => _ab = gewaehlt);
  }

  void _speichern() {
    final gelesen = Finanzrechnung.cents(_betrag.text);
    if (gelesen == null || gelesen == 0) {
      setState(() => _fehler = 'Trag einen Betrag ein, zum Beispiel 94,50.');
      return;
    }
    // Die Richtung übernimmt der Dauerauftrag: aus einer Ausgabe wird
    // nicht durch einen neuen Betrag eine Einnahme.
    final cents = widget.serie.istAusgabe ? -gelesen.abs() : gelesen.abs();
    Navigator.pop(
      context,
      Stufeneingabe(
        gueltigAb: _ab,
        cents: cents,
        notiz: _notiz.text.trim().isEmpty ? null : _notiz.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bisher = widget.serie.aktuellerBetragCents;

    return AlertDialog(
      title: const Text('Neuer Betrag ab Stichtag'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (bisher != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Bisher ${Finanzrechnung.nurBetrag(bisher)}. Was davor '
                'gebucht wurde, bleibt unverändert.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          TextField(
            controller: _betrag,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
                labelText: 'Neuer Betrag', suffixText: '€'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _datum,
            icon: const Icon(Icons.event_rounded),
            label: Text('Gilt ab ${Finanzrechnung.alsDatum(_ab)}'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notiz,
            decoration: const InputDecoration(
              labelText: 'Notiz (optional)',
              hintText: 'Abschlag angepasst',
            ),
          ),
          if (_fehler != null) ...[
            const SizedBox(height: 12),
            Text(_fehler!, style: TextStyle(color: colors.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen')),
        FilledButton(onPressed: _speichern, child: const Text('Übernehmen')),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/haushalt.dart';

/// Das Pop-up beim Annehmen einer Einladung.
///
/// **Es ist nicht überspringbar.** Es hat eine Vorgabe — `nichts` —, also
/// kann man es wegtippen. Aber es muss erschienen sein, damit niemand
/// später sagen kann, er habe nicht gewusst, dass er etwas preisgibt.
///
/// Deshalb führt auch kein zweiter Weg an ihm vorbei: Beitreten geht nur
/// hierdurch, und die Stufe wird ausdrücklich mitgeschickt statt vom
/// Server vorbelegt.
class EinladungDialog extends StatefulWidget {
  final Einladung einladung;

  const EinladungDialog({super.key, required this.einladung});

  /// Gibt die gewählte Stufe zurück — oder null, wenn abgebrochen wurde.
  static Future<Finanzsicht?> zeige(
    BuildContext context, {
    required Einladung einladung,
  }) =>
      showDialog<Finanzsicht>(
        context: context,
        builder: (_) => EinladungDialog(einladung: einladung),
      );

  @override
  State<EinladungDialog> createState() => _EinladungDialogState();
}

class _EinladungDialogState extends State<EinladungDialog> {
  /// Die Vorgabe, und sie ist die Zeile, die man leicht falsch herum
  /// baut: wer beitritt, gibt nichts preis, bis er es ausdrücklich
  /// anders einstellt.
  Finanzsicht _stufe = Finanzsicht.nichts;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final e = widget.einladung;

    return AlertDialog(
      title: Text('„${e.haushaltName}" beitreten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${e.vonName} hat dich eingeladen. Rezepte, Vorrat, '
              'Einkaufszettel und Essensplan des Haushalts seht ihr dann '
              'gemeinsam.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 20),
            Text('Was dürfen die anderen von deinen Finanzen sehen?',
                style: text.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Das entscheidest du, nicht der Haushalt. Du kannst es '
              'jederzeit ändern.',
              style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Stufenwahl(
              stufe: _stufe,
              onGewaehlt: (w) => setState(() => _stufe = w),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _stufe),
          child: const Text('Beitreten'),
        ),
      ],
    );
  }
}

/// Dasselbe Pop-up ohne die Einladung — zum späteren Ändern der eigenen
/// Stufe. Die Erklärungen bleiben dieselben; sie sind der Grund, warum
/// man die Stufe überhaupt versteht.
class FinanzsichtDialog extends StatefulWidget {
  final Finanzsicht aktuell;

  const FinanzsichtDialog({super.key, required this.aktuell});

  static Future<Finanzsicht?> zeige(
    BuildContext context, {
    required Finanzsicht aktuell,
  }) =>
      showDialog<Finanzsicht>(
        context: context,
        builder: (_) => FinanzsichtDialog(aktuell: aktuell),
      );

  @override
  State<FinanzsichtDialog> createState() => _FinanzsichtDialogState();
}

class _FinanzsichtDialogState extends State<FinanzsichtDialog> {
  late Finanzsicht _stufe = widget.aktuell;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Deine Finanzen im Haushalt'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stufenwahl(
              stufe: _stufe,
              onGewaehlt: (w) => setState(() => _stufe = w),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _stufe),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}

/// Die vier Stufen mit ihren Erklärungen.
///
/// Eigenes Widget, weil es die Wahl zweimal gibt: beim Beitreten und
/// beim späteren Ändern. Die Erklärungen sind dabei die eigentliche
/// Arbeit — ohne sie müsste jeder raten, was „Kategorien" preisgibt, und
/// das ist genau die Frage, bei der man sich nicht verschätzen möchte.
class Stufenwahl extends StatelessWidget {
  final Finanzsicht stufe;
  final ValueChanged<Finanzsicht> onGewaehlt;

  const Stufenwahl({
    super.key,
    required this.stufe,
    required this.onGewaehlt,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return RadioGroup<Finanzsicht>(
      groupValue: stufe,
      onChanged: (w) => onGewaehlt(w ?? stufe),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in Finanzsicht.values)
            RadioListTile<Finanzsicht>(
              value: s,
              contentPadding: EdgeInsets.zero,
              title: Text(s.titel),
              subtitle: Text(s.erklaerung,
                  style: text.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}

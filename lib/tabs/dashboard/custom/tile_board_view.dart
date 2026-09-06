import 'package:flutter/material.dart';
import 'package:productivity/tabs/dashboard/custom/tile_data.dart';

/// Ein Kanban-Board als Kachel.
///
/// Spalten nebeneinander, Karten darin — dasselbe Bild wie im
/// Aufgabenbereich, aber **ohne Ziehen**. Eine Kachel wird gelesen; wer
/// eine Aufgabe verschieben will, tut das in der App. In der Küche zählt,
/// dass man aus zwei Metern sieht, was ansteht und was läuft.
///
/// Leere Spalten bleiben stehen. „Nichts in Arbeit" ist eine Auskunft, und
/// eine Spalte, die verschwindet, sobald sie leer ist, lässt das Board bei
/// jedem Wechsel anders aussehen.
class TileBoardView extends StatelessWidget {
  final TileData data;

  /// Grosse Schrift und Karten – fuer ein Geraet an der Wand.
  final bool gross;

  const TileBoardView({super.key, required this.data, this.gross = false});

  @override
  Widget build(BuildContext context) {
    if (data.spalten.isEmpty) return const SizedBox();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Ab dieser Breite passen alle Spalten nebeneinander, ohne dass
        // eine schmaler als lesbar wird. Darunter wird geschoben.
        final mindestBreite = gross ? 230.0 : 170.0;
        final passtNebeneinander =
            constraints.maxWidth >= mindestBreite * data.spalten.length;

        final spalten = [
          for (final s in data.spalten)
            SizedBox(
              width: passtNebeneinander
                  ? (constraints.maxWidth - 12 * (data.spalten.length - 1)) /
                      data.spalten.length
                  : mindestBreite,
              child: _Spalte(spalte: s, gross: gross),
            ),
        ];

        final reihe = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < spalten.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              spalten[i],
            ],
          ],
        );

        if (passtNebeneinander) return reihe;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: reihe,
        );
      },
    );
  }
}

class _Spalte extends StatelessWidget {
  final TileBoardSpalte spalte;
  final bool gross;

  const _Spalte({required this.spalte, required this.gross});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  spalte.titel,
                  style: (gross ? text.titleMedium : text.labelLarge)
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Die Zahl sagt auf einen Blick, wo sich etwas staut.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${spalte.eintraege.length}',
                    style: TextStyle(
                        fontSize: gross ? 14 : 11,
                        color: colors.onSurfaceVariant)),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: spalte.eintraege.isEmpty
                ? Center(
                    child: Text('—',
                        style: TextStyle(color: colors.outline)),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: spalte.eintraege.length,
                    itemBuilder: (_, i) =>
                        _Karte(eintrag: spalte.eintraege[i], gross: gross),
                  ),
          ),
        ),
      ],
    );
  }
}

class _Karte extends StatelessWidget {
  final TileListItem eintrag;
  final bool gross;

  const _Karte({required this.eintrag, required this.gross});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(
          horizontal: 10, vertical: gross ? 12 : 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            eintrag.title,
            style: gross ? text.bodyLarge : text.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (eintrag.subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                eintrag.subtitle!,
                style: (gross ? text.bodyMedium : text.bodySmall)
                    ?.copyWith(color: colors.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

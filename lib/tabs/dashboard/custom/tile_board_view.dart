import 'package:flutter/material.dart';
import 'package:productivity/tabs/dashboard/custom/tile_data.dart';
import 'package:productivity/tabs/dashboard/custom/tile_views.dart';
import 'package:productivity/widgets/platform_draggable.dart';

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
///
/// **Verschieben geht**, wenn der Rückkanal es anbietet: eine Karte auf
/// eine andere Spalte ziehen. Das ist die zweite Kachel nach der
/// Einkaufsliste, die etwas ändert — und aus demselben Grund: eine
/// Aufgabe auf „erledigt" zu schieben ist das, wofür ein Board da ist.
/// Ohne Rückkanal (im Dashboard am Rechner) bleibt es beim Ansehen.
class TileBoardView extends StatefulWidget {
  final TileData data;
  final TileKontext kontext;

  /// Grosse Schrift und Karten – fuer ein Geraet an der Wand.
  final bool gross;

  const TileBoardView({
    super.key,
    required this.data,
    this.kontext = TileKontext.leer,
    this.gross = false,
  });

  @override
  State<TileBoardView> createState() => _TileBoardViewState();
}

class _TileBoardViewState extends State<TileBoardView> {
  /// Was gerade zum Server unterwegs ist – solange bleibt die Karte
  /// unantastbar, sonst schiebt man zweimal und die zweite Antwort
  /// ueberschreibt die erste.
  final Set<String> _unterwegs = {};

  Future<void> _verschieben(TileCheckItem e, TileBoardSpalte ziel) async {
    final f = widget.kontext.verschieben;
    if (f == null || _unterwegs.contains(e.id) || ziel.schluessel.isEmpty) {
      return;
    }
    setState(() => _unterwegs.add(e.id));
    try {
      await f(e.id, ziel.schluessel);
    } finally {
      if (mounted) setState(() => _unterwegs.remove(e.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.spalten.isEmpty) return const SizedBox();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Ab dieser Breite passen alle Spalten nebeneinander, ohne dass
        // eine schmaler als lesbar wird. Darunter wird geschoben.
        final mindestBreite = widget.gross ? 230.0 : 170.0;
        final anzahl = widget.data.spalten.length;
        final passtNebeneinander =
            constraints.maxWidth >= mindestBreite * anzahl;

        final spalten = [
          for (final s in widget.data.spalten)
            SizedBox(
              width: passtNebeneinander
                  ? (constraints.maxWidth - 12 * (anzahl - 1)) / anzahl
                  : mindestBreite,
              child: _Spalte(
                spalte: s,
                gross: widget.gross,
                unterwegs: _unterwegs,
                onAbgelegt: widget.kontext.verschieben == null
                    ? null
                    : (e) => _verschieben(e, s),
              ),
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
  final Set<String> unterwegs;

  /// Null = hier laesst sich nichts ablegen (kein Rueckkanal).
  final void Function(TileCheckItem)? onAbgelegt;

  const _Spalte({
    required this.spalte,
    required this.gross,
    required this.unterwegs,
    this.onAbgelegt,
  });

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
          child: DragTarget<TileCheckItem>(
            // Eine Karte in ihre eigene Spalte zu ziehen ist kein Fehler,
            // aber auch keine Aenderung – dann gar nicht erst anbieten.
            onWillAcceptWithDetails: (d) =>
                onAbgelegt != null &&
                !spalte.eintraege.any((e) => e.id == d.data.id),
            onAcceptWithDetails: (d) => onAbgelegt?.call(d.data),
            builder: (context, kandidaten, _) {
              final zielt = kandidaten.isNotEmpty;
              return Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: zielt
                      ? colors.primary.withValues(alpha: 0.16)
                      : colors.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: zielt
                      ? Border.all(color: colors.primary, width: 2)
                      : null,
                ),
                child: spalte.eintraege.isEmpty
                    ? Center(
                        child: Text(zielt ? 'Hier ablegen' : '—',
                            style: TextStyle(
                                color: zielt ? colors.primary : colors.outline)),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: spalte.eintraege.length,
                        itemBuilder: (_, i) => _Karte(
                          eintrag: spalte.eintraege[i],
                          gross: gross,
                          ziehbar: onAbgelegt != null,
                          laeuft: unterwegs.contains(spalte.eintraege[i].id),
                        ),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Karte extends StatelessWidget {
  final TileCheckItem eintrag;
  final bool gross;
  final bool ziehbar;
  final bool laeuft;

  const _Karte({
    required this.eintrag,
    required this.gross,
    this.ziehbar = false,
    this.laeuft = false,
  });

  @override
  Widget build(BuildContext context) {
    final karte = _inhalt(context);
    if (!ziehbar || laeuft) {
      return Opacity(opacity: laeuft ? 0.4 : 1, child: karte);
    }
    // platformDraggable: am Rechner sofort ziehen, am Tablet erst nach
    // langem Druck – sonst scrollt man die Spalte nie, ohne eine Karte
    // mitzunehmen.
    return platformDraggable<TileCheckItem>(
      data: eintrag,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.9,
          child: SizedBox(width: 200, child: _inhalt(context)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: karte),
      child: karte,
    );
  }

  Widget _inhalt(BuildContext context) {
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
            eintrag.titel,
            style: gross ? text.bodyLarge : text.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (eintrag.untertitel != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                eintrag.untertitel!,
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

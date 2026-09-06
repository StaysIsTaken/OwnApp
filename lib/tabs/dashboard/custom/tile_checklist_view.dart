import 'package:flutter/material.dart';
import 'package:productivity/tabs/dashboard/custom/tile_data.dart';
import 'package:productivity/tabs/dashboard/custom/tile_views.dart';

/// Eine Liste zum Abhaken — die einzige Kachel, die etwas ändert.
///
/// Für eine Einkaufsliste in der Küche ist genau das der Sinn: man hakt ab,
/// während man einräumt, und tippt dazu, was noch fehlt. Alles andere auf
/// dieser Wand zeigt nur.
///
/// Abgehaktes bleibt stehen und rutscht nach unten, statt zu verschwinden.
/// Wer sich verklickt, muss es zurückholen können — und wer im Laden steht,
/// will sehen, was schon im Wagen liegt.
class TileChecklistView extends StatefulWidget {
  final TileData data;
  final TileKontext kontext;

  /// Grosse Zeilen und Kaestchen – fuer ein Geraet an der Wand.
  final bool gross;

  const TileChecklistView({
    super.key,
    required this.data,
    required this.kontext,
    this.gross = false,
  });

  @override
  State<TileChecklistView> createState() => _TileChecklistViewState();
}

class _TileChecklistViewState extends State<TileChecklistView> {
  final _neu = TextEditingController();

  /// Was gerade zum Server unterwegs ist. Solange bleibt die Zeile
  /// unantastbar — sonst klickt man zweimal und die zweite Antwort
  /// überschreibt die erste.
  final Set<String> _unterwegs = {};

  bool _traegtEin = false;

  @override
  void dispose() {
    _neu.dispose();
    super.dispose();
  }

  Future<void> _umschalten(TileCheckItem e) async {
    final f = widget.kontext.umschalten;
    if (f == null || _unterwegs.contains(e.id)) return;
    setState(() => _unterwegs.add(e.id));
    try {
      await f(e.id, !e.erledigt);
    } finally {
      if (mounted) setState(() => _unterwegs.remove(e.id));
    }
  }

  Future<void> _hinzufuegen() async {
    final f = widget.kontext.hinzufuegen;
    final text = _neu.text.trim();
    if (f == null || text.isEmpty || _traegtEin) return;
    setState(() => _traegtEin = true);
    try {
      await f(text);
      if (mounted) _neu.clear();
    } finally {
      if (mounted) setState(() => _traegtEin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Offenes zuerst, Abgehaktes darunter – in der Reihenfolge, in der man
    // es braucht.
    final offen = widget.data.haken.where((e) => !e.erledigt).toList();
    final erledigt = widget.data.haken.where((e) => e.erledigt).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: widget.data.haken.isEmpty
              ? Center(
                  child: Text(widget.data.emptyHint,
                      style: TextStyle(color: colors.onSurfaceVariant)),
                )
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final e in [...offen, ...erledigt]) _zeile(e),
                  ],
                ),
        ),
        if (widget.kontext.hinzufuegen != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _neu,
                  style: TextStyle(fontSize: widget.gross ? 18 : 14),
                  decoration: InputDecoration(
                    hintText: 'Noch etwas?',
                    isDense: !widget.gross,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: widget.gross ? 16 : 10),
                    border: const OutlineInputBorder(),
                  ),
                  // Weiter tippen ohne Griff zur Maus: die Liste waechst
                  // sonst Posten fuer Posten mit einem Klick dazwischen.
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _hinzufuegen(),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed:
                    (_traegtEin || _neu.text.trim().isEmpty) ? null : _hinzufuegen,
                icon: const Icon(Icons.add_rounded),
                iconSize: widget.gross ? 28 : 22,
                tooltip: 'Auf die Liste setzen',
              ),
            ],
          ),
        ],
        if (erledigt.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${erledigt.length} von ${widget.data.haken.length} erledigt',
              style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  Widget _zeile(TileCheckItem e) {
    final colors = Theme.of(context).colorScheme;
    final laeuft = _unterwegs.contains(e.id);

    return InkWell(
      onTap: widget.kontext.umschalten == null ? null : () => _umschalten(e),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: widget.gross ? 10 : 4),
        child: Row(
          children: [
            SizedBox(
              width: widget.gross ? 34 : 26,
              height: widget.gross ? 34 : 26,
              child: laeuft
                  ? const Padding(
                      padding: EdgeInsets.all(6),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Checkbox(
                      value: e.erledigt,
                      onChanged: widget.kontext.umschalten == null
                          ? null
                          : (_) => _umschalten(e),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    e.titel,
                    style: TextStyle(
                      fontSize: widget.gross ? 18 : 14,
                      decoration:
                          e.erledigt ? TextDecoration.lineThrough : null,
                      color: e.erledigt ? colors.outline : colors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (e.untertitel != null)
                    Text(
                      e.untertitel!,
                      style: TextStyle(
                        fontSize: widget.gross ? 14 : 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

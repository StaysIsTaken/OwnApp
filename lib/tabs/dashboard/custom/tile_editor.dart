import 'package:flutter/material.dart';
import 'package:productivity/tabs/dashboard/custom/filter_editor.dart';
import 'package:productivity/tabs/dashboard/custom/tile_catalog.dart';
import 'package:productivity/tabs/dashboard/custom/tile_filter.dart';
import 'package:productivity/tabs/dashboard/custom/tile_spec.dart';
import 'package:productivity/tabs/dashboard/custom/tile_views.dart';

/// Dialog zum Anlegen und Bearbeiten einer eigenen Kachel.
///
/// Ablauf: Quelle wählen → Darstellung wählen (nur passende zur Datenform der
/// Quelle) → Feineinstellungen. Dadurch kann keine unmögliche Kombination
/// entstehen, ohne dass irgendwo eine Liste erlaubter Paarungen gepflegt wird.
Future<CustomTile?> showTileEditor(
  BuildContext context, {
  CustomTile? vorhanden,
}) {
  return showDialog<CustomTile>(
    context: context,
    builder: (ctx) => _TileEditor(vorhanden: vorhanden),
  );
}

class _TileEditor extends StatefulWidget {
  final CustomTile? vorhanden;
  const _TileEditor({this.vorhanden});

  @override
  State<_TileEditor> createState() => _TileEditorState();
}

class _TileEditorState extends State<_TileEditor> {
  TileSource? _quelle;
  TileView? _darstellung;
  late final TextEditingController _titel;
  final Map<String, int> _werte = {};
  List<FilterRule> _filter = [];

  @override
  void initState() {
    super.initState();
    final v = widget.vorhanden;
    _titel = TextEditingController(text: v?.title ?? '');
    if (v != null) {
      _quelle = TileCatalog.byKey(v.source);
      _darstellung = TileViews.byKey(v.view);
      for (final p in _quelle?.params ?? const <TileParam>[]) {
        final gespeichert = v.params[p.key];
        _werte[p.key] = gespeichert is num ? gespeichert.toInt() : p.standard;
      }
      _filter = List<FilterRule>.from(v.filters);
    }
  }

  @override
  void dispose() {
    _titel.dispose();
    super.dispose();
  }

  void _waehleQuelle(TileSource s) {
    setState(() {
      _quelle = s;
      // Passt die bisherige Darstellung nicht zur neuen Datenform, die erste
      // passende nehmen – sonst stünde da eine unmögliche Kombination.
      final passende = TileViews.forShape(s.shape);
      if (_darstellung == null || !passende.contains(_darstellung)) {
        _darstellung = passende.isNotEmpty ? passende.first : null;
      }
      _werte.clear();
      for (final p in s.params) {
        _werte[p.key] = p.standard;
      }
      // Andere Quelle heisst andere Felder – alte Bedingungen passen nicht mehr.
      _filter = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final bearbeiten = widget.vorhanden != null;
    final passende =
        _quelle == null ? <TileView>[] : TileViews.forShape(_quelle!.shape);

    return AlertDialog(
      title: Text(bearbeiten ? 'Kachel bearbeiten' : 'Kachel hinzufügen'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            // ── Quelle ──────────────────────────────────
            Text('Was soll angezeigt werden?', style: text.labelLarge),
            const SizedBox(height: 8),
            for (final eintrag in TileCatalog.grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(eintrag.key,
                    style: text.labelSmall
                        ?.copyWith(color: colors.onSurfaceVariant)),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in eintrag.value)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: _quelle?.key == s.key,
                      onSelected: (_) => _waehleQuelle(s),
                    ),
                ],
              ),
            ],

            // ── Darstellung ─────────────────────────────
            if (_quelle != null) ...[
              const SizedBox(height: 20),
              Text('Wie soll es aussehen?', style: text.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final v in passende)
                    ChoiceChip(
                      avatar: Icon(v.icon, size: 18),
                      label: Text(v.label),
                      selected: _darstellung?.key == v.key,
                      onSelected: (_) => setState(() => _darstellung = v),
                    ),
                ],
              ),
              if (passende.length == 1)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Für diese Daten gibt es nur diese Darstellung.',
                    style: text.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
            ],

            // ── Feineinstellungen ───────────────────────
            if (_quelle != null && _quelle!.params.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Feineinstellung', style: text.labelLarge),
              for (final p in _quelle!.params)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(p.label, style: text.bodyMedium)),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: (_werte[p.key] ?? p.standard) > p.min
                            ? () => setState(() => _werte[p.key] =
                                (_werte[p.key] ?? p.standard) - 1)
                            : null,
                      ),
                      SizedBox(
                        width: 32,
                        child: Text('${_werte[p.key] ?? p.standard}',
                            textAlign: TextAlign.center,
                            style: text.titleMedium),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: (_werte[p.key] ?? p.standard) < p.max
                            ? () => setState(() => _werte[p.key] =
                                (_werte[p.key] ?? p.standard) + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
            ],

            // ── Filter ──────────────────────────────────
            if (_quelle != null && _quelle!.filterable) ...[
              const SizedBox(height: 20),
              FilterEditor(
                fields: _quelle!.fields,
                rules: _filter,
                onChanged: (r) => setState(() => _filter = r),
              ),
            ],

            // ── Titel ───────────────────────────────────
            if (_quelle != null) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _titel,
                decoration: InputDecoration(
                  labelText: 'Eigene Überschrift (optional)',
                  hintText: _quelle!.label,
                ),
              ),
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
          onPressed: (_quelle == null || _darstellung == null)
              ? null
              : () {
                  final titel = _titel.text.trim();
                  Navigator.pop(
                    context,
                    CustomTile(
                      id: widget.vorhanden?.id ??
                          'ct_${DateTime.now().microsecondsSinceEpoch}',
                      source: _quelle!.key,
                      view: _darstellung!.key,
                      title: titel.isEmpty ? null : titel,
                      params: Map<String, dynamic>.from(_werte),
                      filters: _filter,
                    ),
                  );
                },
          child: Text(bearbeiten ? 'Speichern' : 'Hinzufügen'),
        ),
      ],
    );
  }
}

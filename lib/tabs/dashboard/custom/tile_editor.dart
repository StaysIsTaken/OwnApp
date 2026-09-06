import 'package:flutter/material.dart';
import 'package:productivity/tabs/dashboard/custom/custom_tile_card.dart';
import 'package:productivity/tabs/dashboard/custom/filter_editor.dart';
import 'package:productivity/tabs/dashboard/custom/tile_catalog.dart';
import 'package:productivity/tabs/dashboard/custom/tile_filter.dart';
import 'package:productivity/tabs/dashboard/custom/tile_spec.dart';
import 'package:productivity/tabs/dashboard/custom/tile_views.dart';

/// Anlegen und Bearbeiten einer eigenen Kachel.
///
/// Ablauf wie bisher: Quelle wählen → Darstellung wählen (nur passende zur
/// Datenform der Quelle) → Feineinstellungen → Filter. Dadurch kann keine
/// unmögliche Kombination entstehen, ohne dass irgendwo eine Liste
/// erlaubter Paarungen gepflegt wird.
///
/// Was sich geändert hat, ist die Form. Vorher standen vier Abschnitte in
/// einem engen Dialog übereinander, jeder mit einer knappen Überschrift und
/// sonst nichts — man musste raten, was eine Einstellung bewirkt, und
/// sah es erst nach dem Speichern. Jetzt:
///
/// * **Voller Bildschirm** statt Dialogkasten. Platz ist keine Kostbarkeit.
/// * **Nummerierte Schritte** mit je einem Satz, was der Schritt tut.
/// * **Vorschau**, die mitläuft. Auf breiten Geräten daneben, auf schmalen
///   darunter — die Frage „was macht dieses Feld" beantwortet sich damit
///   von selbst, statt erklärt werden zu müssen.
Future<CustomTile?> showTileEditor(
  BuildContext context, {
  CustomTile? vorhanden,
  String zone = CustomTile.zoneRaster,
  DashboardData? daten,
}) {
  return showDialog<CustomTile>(
    context: context,
    // Beim Bearbeiten bleibt der Bereich der Kachel, beim Anlegen zählt der
    // übergebene – sonst wanderte eine Kopfkarte beim Ändern ins Raster.
    builder: (ctx) => _TileEditor(
      vorhanden: vorhanden,
      zone: vorhanden?.zone ?? zone,
      daten: daten ?? const DashboardData(),
    ),
  );
}

class _TileEditor extends StatefulWidget {
  final CustomTile? vorhanden;

  /// In welchen Bereich die neue Kachel gehört. Die Auswahl der Quellen ist
  /// dieselbe – der Bereich entscheidet nur, wo sie landet und wie breit sie
  /// gezeigt wird.
  final String zone;

  /// Echte Daten für die Vorschau. Ohne sie zeigt die Vorschau den
  /// Leer-Hinweis der Quelle — immer noch nützlich, aber weniger.
  final DashboardData daten;

  const _TileEditor({
    this.vorhanden,
    this.zone = CustomTile.zoneRaster,
    this.daten = const DashboardData(),
  });

  @override
  State<_TileEditor> createState() => _TileEditorState();
}

class _TileEditorState extends State<_TileEditor> {
  TileSource? _quelle;
  TileView? _darstellung;
  late final TextEditingController _titel;
  // Zahlen, Texte und Datumsangaben – je nach Art der Einstellung.
  final Map<String, dynamic> _werte = {};
  final Map<String, TextEditingController> _textfelder = {};
  List<FilterRule> _filter = [];

  /// 0 = automatisch. Die Darstellung entscheidet dann.
  int _breite = CustomTile.automatisch;
  int _hoehe = CustomTile.automatisch;

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
        _werte[p.key] = switch (p.art) {
          ParamArt.zahl =>
            gespeichert is num ? gespeichert.toInt() : p.standard,
          _ => gespeichert?.toString() ?? '',
        };
      }
      _filter = List<FilterRule>.from(v.filters);
      _breite = v.breite;
      _hoehe = v.hoehe;
    }
  }

  @override
  void dispose() {
    _titel.dispose();
    for (final c in _textfelder.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Ein Feld je Text-Einstellung, ueber Neubauten hinweg dasselbe – sonst
  /// springt der Cursor bei jedem Tastendruck an den Anfang.
  TextEditingController _feld(TileParam p) => _textfelder.putIfAbsent(
        p.key,
        () => TextEditingController(text: _werte[p.key]?.toString() ?? ''),
      );

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
      for (final c in _textfelder.values) {
        c.dispose();
      }
      _textfelder.clear();
      for (final p in s.params) {
        _werte[p.key] = p.art == ParamArt.zahl ? p.standard : '';
      }
      // Andere Quelle heisst andere Felder – alte Bedingungen passen nicht mehr.
      _filter = [];
    });
  }

  /// Die Kachel, wie sie gerade zusammengestellt ist — für die Vorschau und
  /// zum Speichern. Eine Stelle, damit die Vorschau nicht etwas anderes
  /// zeigt, als am Ende herauskommt.
  CustomTile? get _entwurf {
    if (_quelle == null || _darstellung == null) return null;
    final titel = _titel.text.trim();
    return CustomTile(
      zone: widget.zone,
      id: widget.vorhanden?.id ?? 'ct_${DateTime.now().microsecondsSinceEpoch}',
      source: _quelle!.key,
      view: _darstellung!.key,
      title: titel.isEmpty ? null : titel,
      params: Map<String, dynamic>.from(_werte),
      filters: _filter,
      breite: _breite,
      hoehe: _hoehe,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bearbeiten = widget.vorhanden != null;

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(bearbeiten ? 'Kachel bearbeiten' : 'Neue Kachel'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Abbrechen',
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton(
                onPressed: _entwurf == null
                    ? null
                    : () => Navigator.pop(context, _entwurf),
                child: Text(bearbeiten ? 'Speichern' : 'Hinzufügen'),
              ),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            // Ab dieser Breite passt die Vorschau daneben. Darunter kommt
            // sie oben ans Formular – gequetscht nebeneinander wäre beides
            // unlesbar.
            final breit = constraints.maxWidth >= 900;
            final formular = _formular();
            final vorschau = _vorschau();

            if (!breit) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
                children: [vorschau, const SizedBox(height: 32), ...formular],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(40, 32, 32, 60),
                    children: formular,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(32, 32, 40, 60),
                    child: vorschau,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Die Vorschau ───────────────────────────────────────────────────────

  Widget _vorschau() {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final entwurf = _entwurf;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vorschau', style: text.titleSmall),
        const SizedBox(height: 4),
        Text(
          'So sieht die Kachel gleich aus – mit deinen echten Daten.',
          style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        if (entwurf == null)
          Container(
            height: 160,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Wähle links, was angezeigt werden soll.',
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          )
        else
          // Ohne Aktionsknopf und ohne Ziehgriff: hier wird gezeigt, wie sie
          // aussieht, nicht was sie kann.
          AbsorbPointer(
            child: CustomTileCard(tile: entwurf, data: widget.daten),
          ),
      ],
    );
  }

  // ── Das Formular ───────────────────────────────────────────────────────

  List<Widget> _formular() {
    final passende =
        _quelle == null ? <TileView>[] : TileViews.forShape(_quelle!.shape);

    return [
      _Schritt(
        nummer: 1,
        titel: 'Was soll angezeigt werden?',
        erklaerung: 'Die Datenquelle. Sie bestimmt, was in der Kachel steht '
            'und welche Darstellungen im nächsten Schritt zur Wahl stehen.',
        child: _quellenwahl(),
      ),
      if (_quelle != null)
        _Schritt(
          nummer: 2,
          titel: 'Wie soll es aussehen?',
          erklaerung: passende.length == 1
              ? 'Für diese Art von Daten gibt es genau eine sinnvolle '
                  'Darstellung – deshalb steht hier nur eine zur Wahl.'
              : 'Nur passende Darstellungen: eine Torte braucht Anteile, '
                  'eine Linie einen Verlauf. Was nicht passt, steht gar '
                  'nicht erst hier.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final v in passende)
                ChoiceChip(
                  avatar: Icon(v.icon, size: 20),
                  label: Text(v.label),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  selected: _darstellung?.key == v.key,
                  onSelected: (_) => setState(() => _darstellung = v),
                ),
            ],
          ),
        ),
      if (_quelle != null && _quelle!.params.isNotEmpty)
        _Schritt(
          nummer: 3,
          titel: 'Feineinstellung',
          erklaerung: 'Wie viel und wie weit zurück. Die Vorschau ändert '
              'sich sofort mit.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final p in _quelle!.params)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: p.art == ParamArt.zahl
                      ? _zahlZeile(p)
                      : _eingabeZeile(p),
                ),
            ],
          ),
        ),
      if (_quelle != null && _quelle!.filterable)
        _Schritt(
          nummer: _quelle!.params.isNotEmpty ? 4 : 3,
          titel: 'Nur bestimmte Einträge',
          erklaerung: 'Bedingungen wie „Priorität ist hoch". Ohne Bedingung '
              'zählt alles. Was du auswählen kannst, richtet sich nach dem '
              'Datentyp der Spalte.',
          child: FilterEditor(
            fields: _quelle!.fields,
            rules: _filter,
            onChanged: (r) => setState(() => _filter = r),
          ),
        ),
      if (_quelle != null)
        _Schritt(
          nummer: _naechsteNummer - 1,
          titel: 'Größe auf der Seite',
          erklaerung: 'Gilt für die Küchenansicht. „Automatisch" heißt: ein '
              'Kalender oder Board nimmt sich die ganze Breite, alles '
              'andere eine Spalte. Zwei schmale Kacheln nebeneinander '
              'ergeben zwei Spalten.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _stufenwahl(
                titel: 'Breite',
                wert: _breite,
                max: CustomTile.maxBreite,
                namen: const ['1 Spalte', '2 Spalten', '3 Spalten', 'ganze Reihe'],
                onGewaehlt: (v) => setState(() => _breite = v),
              ),
              const SizedBox(height: 16),
              _stufenwahl(
                titel: 'Höhe',
                wert: _hoehe,
                max: CustomTile.maxHoehe,
                namen: const ['flach', 'mittel', 'hoch', 'ganze Seite'],
                onGewaehlt: (v) => setState(() => _hoehe = v),
              ),
            ],
          ),
        ),
      if (_quelle != null)
        _Schritt(
          nummer: _naechsteNummer,
          titel: 'Überschrift',
          erklaerung: 'Freilassen genügt – dann steht der Name der '
              'Datenquelle darüber.',
          letzter: true,
          child: TextField(
            controller: _titel,
            decoration: InputDecoration(
              labelText: 'Eigene Überschrift',
              hintText: _quelle!.label,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
    ];
  }

  /// Die Nummer des letzten Schritts – hängt davon ab, welche davor
  /// überhaupt vorkommen. Der Größenschritt liegt immer direkt davor.
  int get _naechsteNummer {
    var n = 3; // Quelle, Darstellung, Größe
    if (_quelle!.params.isNotEmpty) n++;
    if (_quelle!.filterable) n++;
    return n + 1;
  }

  /// Eine Reihe aus „Automatisch" und den festen Stufen.
  Widget _stufenwahl({
    required String titel,
    required int wert,
    required int max,
    required List<String> namen,
    required ValueChanged<int> onGewaehlt,
  }) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titel, style: text.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Automatisch'),
              selected: wert == CustomTile.automatisch,
              onSelected: (_) => onGewaehlt(CustomTile.automatisch),
            ),
            for (var i = 1; i <= max; i++)
              ChoiceChip(
                label: Text(namen[i - 1]),
                selected: wert == i,
                onSelected: (_) => onGewaehlt(i),
              ),
          ],
        ),
      ],
    );
  }

  Widget _quellenwahl() {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final eintrag in TileCatalog.grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              eintrag.key,
              style: text.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final s in eintrag.value)
                ChoiceChip(
                  label: Text(s.label),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  selected: _quelle?.key == s.key,
                  onSelected: (_) => _waehleQuelle(s),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// Zahl mit Plus und Minus – jetzt mit Luft und mit dem Wert groß in der
  /// Mitte, damit man ihn aus dem Augenwinkel liest.
  Widget _zahlZeile(TileParam p) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final wert = (_werte[p.key] as num?)?.toInt() ?? p.standard;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: Text(p.label, style: text.bodyLarge)),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'Weniger',
            onPressed: wert > p.min
                ? () => setState(() => _werte[p.key] = wert - 1)
                : null,
          ),
          SizedBox(
            width: 44,
            child: Text('$wert',
                textAlign: TextAlign.center,
                style: text.titleLarge?.copyWith(color: colors.primary)),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Mehr',
            onPressed: wert < p.max
                ? () => setState(() => _werte[p.key] = wert + 1)
                : null,
          ),
        ],
      ),
    );
  }

  /// Text, mehrzeiliger Text oder ein Datum.
  Widget _eingabeZeile(TileParam p) {
    if (p.art == ParamArt.datum) {
      final roh = _werte[p.key]?.toString();
      final gewaehlt = roh == null || roh.isEmpty ? null : DateTime.tryParse(roh);
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          alignment: Alignment.centerLeft,
        ),
        icon: const Icon(Icons.event_outlined),
        label: Text(gewaehlt == null
            ? '${p.label}: noch keins gewählt'
            : '${p.label}: ${gewaehlt.day}.${gewaehlt.month}.${gewaehlt.year}'),
        onPressed: () async {
          final heute = DateTime.now();
          final d = await showDatePicker(
            context: context,
            initialDate: gewaehlt ?? heute,
            // Auch rueckwaerts: ein Countdown taugt genauso zum Zaehlen,
            // wie lange etwas her ist.
            firstDate: DateTime(heute.year - 10),
            lastDate: DateTime(heute.year + 20),
          );
          if (d != null) {
            setState(() => _werte[p.key] =
                '${d.year}-${d.month.toString().padLeft(2, '0')}-'
                '${d.day.toString().padLeft(2, '0')}');
          }
        },
      );
    }

    return TextField(
      controller: _feld(p),
      maxLines: p.art == ParamArt.mehrzeilig ? 8 : 1,
      minLines: p.art == ParamArt.mehrzeilig ? 4 : 1,
      decoration: InputDecoration(
        labelText: p.label,
        hintText: p.platzhalter,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
      ),
      // Mitschreiben statt nur merken: sonst zeigt die Vorschau den Text
      // erst nach dem Speichern.
      onChanged: (v) => setState(() => _werte[p.key] = v),
    );
  }
}

/// Ein nummerierter Schritt mit Überschrift, Erklärung und Inhalt.
///
/// Die Erklärung ist der eigentliche Punkt: vorher stand über jedem
/// Abschnitt eine Zeile wie „Feineinstellung" und sonst nichts.
class _Schritt extends StatelessWidget {
  final int nummer;
  final String titel;
  final String erklaerung;
  final Widget child;
  final bool letzter;

  const _Schritt({
    required this.nummer,
    required this.titel,
    required this.erklaerung,
    required this.child,
    this.letzter = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Text('$nummer',
                  style: text.labelLarge
                      ?.copyWith(color: colors.onPrimaryContainer)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titel,
                      style:
                          text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    erklaerung,
                    style: text.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Eingerückt auf Höhe des Textes, damit die Nummer die Spalte führt.
        Padding(
          padding: const EdgeInsets.fromLTRB(42, 16, 0, 0),
          child: child,
        ),
        if (!letzter) const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Divider(height: 1),
        ),
      ],
    );
  }
}

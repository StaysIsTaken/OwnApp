import 'dart:async';

import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/einkauf.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/dataservice/einkauf_service.dart';

/// Eine Einkaufsliste mit ihren Positionen.
///
/// Fürs Telefon gebaut, und zwar für die Hand, die gerade einen Einkaufswagen
/// schiebt:
///
/// * **Das Eingabefeld sitzt unten**, in Daumenreichweite, und bleibt nach
///   dem Absenden offen. Wer eine Liste schreibt, schreibt mehrere Zeilen
///   hintereinander — jedes Mal neu antippen wäre eine Zumutung.
/// * **Abgehaktes verschwindet** und lässt sich mit einem Schalter wieder
///   einblenden. Zum Zurückholen, wenn man sich verklickt hat, und um zu
///   sehen, was schon im Wagen liegt.
/// * **Der Preishinweis erscheint beim Tippen.** „Bei Aldi zuletzt 0,89" —
///   dort, wo man ihn braucht, nicht auf einer anderen Seite.
class EinkaufslistePage extends StatefulWidget {
  final Einkaufsliste liste;

  const EinkaufslistePage({super.key, required this.liste});

  @override
  State<EinkaufslistePage> createState() => _EinkaufslistePageState();
}

class _EinkaufslistePageState extends State<EinkaufslistePage> {
  List<Einkaufsposition> _positionen = [];
  bool _laedt = true;
  String? _fehler;

  /// Ob Abgehaktes mitgezeigt wird. Standardmäßig nicht — eine Liste, auf
  /// der alles stehenbleibt, wird beim Einkaufen unlesbar.
  bool _zeigeErledigte = false;

  final _neu = TextEditingController();
  final _neuFokus = FocusNode();
  bool _traegtEin = false;

  /// Was gerade zum Server unterwegs ist. Solange bleibt die Zeile
  /// unantastbar — sonst hakt man zweimal und die zweite Antwort
  /// überschreibt die erste.
  final Set<int> _unterwegs = {};

  /// Preise zum gerade getippten Namen.
  List<Warenpreis> _preishinweis = [];
  Timer? _preisWarten;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  @override
  void dispose() {
    _preisWarten?.cancel();
    _neu.dispose();
    _neuFokus.dispose();
    super.dispose();
  }

  Future<void> _laden() async {
    setState(() => _laedt = true);
    try {
      final positionen = await EinkaufService.positionen(widget.liste.id);
      if (!mounted) return;
      setState(() {
        _positionen = positionen;
        _laedt = false;
        _fehler = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _laedt = false;
        _fehler = ApiFehler.text(e);
      });
    }
  }

  /// Fragt das Preisgedächtnis — aber nicht bei jedem Tastendruck.
  ///
  /// Eine halbe Sekunde Ruhe: sonst geht für „Milch" fünfmal eine Anfrage
  /// raus, und die Antwort auf „Mil" ist ohnehin wertlos.
  void _preisePruefen(String text) {
    _preisWarten?.cancel();
    final name = text.trim();
    if (name.length < 3) {
      if (_preishinweis.isNotEmpty) setState(() => _preishinweis = []);
      return;
    }
    _preisWarten = Timer(const Duration(milliseconds: 500), () async {
      final preise = await EinkaufService.preise(name);
      if (!mounted || _neu.text.trim() != name) return;
      setState(() => _preishinweis = preise);
    });
  }

  Future<void> _hinzufuegen() async {
    final name = _neu.text.trim();
    if (name.isEmpty || _traegtEin) return;
    setState(() => _traegtEin = true);
    try {
      final position =
          await EinkaufService.positionAnlegen(widget.liste.id, name: name);
      if (!mounted) return;
      setState(() {
        _positionen = [..._positionen, position];
        _neu.clear();
        _preishinweis = [];
        _traegtEin = false;
      });
      // Fokus behalten: die naechste Zeile folgt gleich.
      _neuFokus.requestFocus();
    } catch (e) {
      if (!mounted) return;
      setState(() => _traegtEin = false);
      _melde(ApiFehler.text(e));
    }
  }

  Future<void> _umschalten(Einkaufsposition p) async {
    if (_unterwegs.contains(p.id)) return;
    setState(() => _unterwegs.add(p.id));
    try {
      final neu = await EinkaufService.positionAendern(p.id,
          erledigt: !p.erledigt);
      if (!mounted) return;
      setState(() {
        _positionen =
            _positionen.map((e) => e.id == p.id ? neu : e).toList();
      });
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    } finally {
      if (mounted) setState(() => _unterwegs.remove(p.id));
    }
  }

  Future<void> _loeschen(Einkaufsposition p) async {
    setState(() => _positionen =
        _positionen.where((e) => e.id != p.id).toList());
    try {
      await EinkaufService.positionLoeschen(p.id);
    } catch (e) {
      // Zurueckholen: die Zeile ist noch da, wir haben sie nur zu frueh
      // ausgeblendet.
      if (mounted) {
        _melde(ApiFehler.text(e));
        await _laden();
      }
    }
  }

  Future<void> _aufraeumen() async {
    try {
      final weg = await EinkaufService.aufraeumen(widget.liste.id);
      if (!mounted) return;
      _melde(weg == 1 ? '1 Position weggeräumt.' : '$weg Positionen weggeräumt.');
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  /// Bucht das Abgehakte in den Vorrat.
  ///
  /// Mit Rückfrage, weil es zwei Dinge auf einmal tut: hochbuchen UND von
  /// der Liste räumen. Was liegen blieb, steht in der Meldung — sonst sucht
  /// jemand die Batterien im Vorrat.
  Future<void> _inDenVorrat(int anzahlErledigt) async {
    final ja = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('In den Vorrat buchen?'),
        content: Text(
          anzahlErledigt == 1
              ? 'Der abgehakte Posten wird dem Vorrat gutgeschrieben und '
                  'von der Liste genommen.'
              : 'Die $anzahlErledigt abgehakten Posten werden dem Vorrat '
                  'gutgeschrieben und von der Liste genommen.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Buchen')),
        ],
      ),
    );
    if (ja != true) return;

    try {
      final ergebnis = await EinkaufService.inDenVorrat(widget.liste.id);
      if (!mounted) return;
      _melde(ergebnis.meldung);
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  void _melde(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final offen = _positionen.where((p) => !p.erledigt).toList();
    final erledigt = _positionen.where((p) => p.erledigt).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.liste.name),
        actions: [
          if (erledigt.isNotEmpty)
            IconButton(
              icon: Icon(_zeigeErledigte
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              tooltip: _zeigeErledigte
                  ? 'Abgehaktes ausblenden'
                  : 'Abgehaktes einblenden (${erledigt.length})',
              onPressed: () =>
                  setState(() => _zeigeErledigte = !_zeigeErledigte),
            ),
          // Vor dem Wegräumen: wer erst räumt, kann nicht mehr buchen.
          if (erledigt.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.kitchen_outlined),
              tooltip: 'Abgehaktes in den Vorrat buchen',
              onPressed: () => _inDenVorrat(erledigt.length),
            ),
          if (erledigt.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.cleaning_services_outlined),
              tooltip: 'Abgehaktes wegräumen',
              onPressed: _aufraeumen,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _laedt
                ? const Center(child: CircularProgressIndicator())
                : _fehler != null
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(_fehler!, textAlign: TextAlign.center)))
                    : RefreshIndicator(
                        onRefresh: _laden,
                        child: _inhalt(offen, erledigt, colors),
                      ),
          ),
          _eingabe(colors),
        ],
      ),
    );
  }

  Widget _inhalt(List<Einkaufsposition> offen,
      List<Einkaufsposition> erledigt, ColorScheme colors) {
    if (offen.isEmpty && (erledigt.isEmpty || !_zeigeErledigte)) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(erledigt.isEmpty ? Icons.list_alt_outlined : Icons.check_circle_outline,
              size: 56, color: colors.outline),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              erledigt.isEmpty
                  ? 'Nichts auf der Liste.\nUnten eintippen.'
                  : 'Alles abgehakt.\n'
                      '${erledigt.length} erledigt — oben einblendbar.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final p in offen) _zeile(p, colors),
        if (_zeigeErledigte && erledigt.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                Text('Abgehakt',
                    style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(child: Divider(color: colors.outlineVariant)),
              ],
            ),
          ),
          for (final p in erledigt) _zeile(p, colors),
        ],
      ],
    );
  }

  Widget _zeile(Einkaufsposition p, ColorScheme colors) {
    final laeuft = _unterwegs.contains(p.id);
    final beischrift = p.beischrift(null);

    return Dismissible(
      key: ValueKey(p.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: colors.errorContainer,
        child: Icon(Icons.delete_outline, color: colors.onErrorContainer),
      ),
      onDismissed: (_) => _loeschen(p),
      child: InkWell(
        onTap: () => _umschalten(p),
        child: Padding(
          // Hoehe fuer den Daumen: 56 Pixel sind das Mindestmass, das man
          // im Gehen trifft.
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 32,
                child: laeuft
                    ? const Padding(
                        padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Checkbox(
                        value: p.erledigt,
                        onChanged: (_) => _umschalten(p),
                      ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.name,
                      style: TextStyle(
                        fontSize: 17,
                        decoration:
                            p.erledigt ? TextDecoration.lineThrough : null,
                        color: p.erledigt ? colors.outline : colors.onSurface,
                      ),
                    ),
                    if (beischrift.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(beischrift,
                            style: TextStyle(
                                fontSize: 13,
                                color: colors.onSurfaceVariant)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eingabe(ColorScheme colors) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Der Hinweis steht ueber dem Feld, damit ihn die Tastatur nicht
            // verdeckt.
            if (_preishinweis.isNotEmpty) _preise(colors),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _neu,
                    focusNode: _neuFokus,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(fontSize: 17),
                    decoration: const InputDecoration(
                      hintText: 'Was fehlt?',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                    ),
                    onChanged: (v) {
                      setState(() {});
                      _preisePruefen(v);
                    },
                    onSubmitted: (_) => _hinzufuegen(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: (_traegtEin || _neu.text.trim().isEmpty)
                      ? null
                      : _hinzufuegen,
                  icon: const Icon(Icons.add_rounded),
                  iconSize: 26,
                  tooltip: 'Auf die Liste',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// „Bei Aldi zuletzt 0,89" — der Grund für das ganze Preisgedächtnis.
  Widget _preise(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.savings_outlined, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final preis in _preishinweis.take(4))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          '${preis.shopName} ${preis.alsText()}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

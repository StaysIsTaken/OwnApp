import 'dart:async';

import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/einkauf.dart';
import 'package:productivity/dataservice/preisvergleich.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/dataclasses/finanzen.dart';
import 'package:productivity/dataclasses/shop.dart';
import 'package:productivity/dataservice/finanz_service.dart';
import 'package:productivity/dataservice/shop_service.dart';
import 'package:productivity/provider/permission_provider.dart';
import 'package:productivity/tabs/finanzen/buchung_dialog.dart';
import 'package:provider/provider.dart';
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
  bool _rechnet = false;

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

  /// Den abgehakten Einkauf als Ausgabe buchen.
  ///
  /// Vier Schritte: Laden wählen, Vorschlag holen, Dialog mit dem Betrag
  /// **vorbelegt und änderbar**, buchen.
  ///
  /// Das Änderbare ist der Punkt. Die Summe kommt aus Preisen, die
  /// irgendwann notiert wurden — sie ist eine Schätzung und kein
  /// Kassenbon. Wer den Bon in der Hand hat, gewinnt gegen das
  /// Gedächtnis.
  Future<void> _alsAusgabeBuchen() async {
    final laeden = await _laeden();
    if (laeden == null || !mounted) return;
    if (laeden.isEmpty) {
      _melde('Noch kein Laden angelegt — ohne den gibt es keine Preise.');
      return;
    }

    final laden = laeden.length == 1
        ? laeden.first
        : await showModalBottomSheet<Shop>(
            context: context,
            showDragHandle: true,
            builder: (_) => _Ladenwahl(laeden: laeden),
          );
    if (laden == null || !mounted) return;

    setState(() => _rechnet = true);
    Buchungsvorschlag vorschlag;
    List<Kasse> kassen;
    List<Finanzkategorie> kategorien;
    try {
      vorschlag = await EinkaufService.buchungsvorschlag(
          widget.liste.id, shopId: laden.id);
      kassen = await FinanzService.kassen();
      kategorien = await FinanzService.kategorien();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
      return;
    } finally {
      if (mounted) setState(() => _rechnet = false);
    }
    if (!mounted) return;

    if (kassen.isEmpty) {
      _melde('Erst eine Kasse im Haushaltsbuch anlegen.');
      return;
    }

    final eingabe = await BuchungDialog.zeige(
      context,
      kassen: kassen,
      kategorien: kategorien,
      betragVorgabe: vorschlag.summeCents,
      titelVorgabe: '${widget.liste.name} bei ${vorschlag.laden}',
      hinweis: _herkunft(vorschlag),
    );
    if (eingabe == null) return;

    try {
      await FinanzService.buchen(
        kasseId: eingabe.kasseId,
        tag: eingabe.tag,
        cents: eingabe.cents,
        titel: eingabe.titel,
        kategorieId: eingabe.kategorieId,
        notiz: eingabe.notiz ?? _herkunft(vorschlag),
        externeKennung: EinkaufService.einkaufsKennung(
            widget.liste.id, eingabe.tag),
      );
      if (mounted) _melde('Als Ausgabe gebucht.');
    } catch (e) {
      // 409: derselbe Einkauf steht an diesem Tag schon im Kassenbuch.
      // Das ist keine Panne, sondern der Schutz, der greifen soll —
      // entsprechend liest sich die Meldung.
      if (!mounted) return;
      _melde(ApiFehler.istKonflikt(e)
          ? 'Dieser Einkauf ist heute schon gebucht. Ändern geht im '
              'Haushaltsbuch.'
          : ApiFehler.text(e));
    }
  }

  /// Woher die Zahl kommt — steht über dem Betragsfeld und in der Notiz.
  ///
  /// Ohne diesen Satz sähe der Betrag aus wie eine Tatsache. Und wer ihn
  /// später im Kassenbuch wiederfindet, soll erkennen können, dass er
  /// geschätzt war.
  String _herkunft(Buchungsvorschlag v) {
    if (v.leer) {
      return 'Für keinen der abgehakten Posten ist bei ${v.laden} ein Preis '
          'bekannt — trag den Betrag von Hand ein.';
    }
    final grund = 'Geschätzt aus ${v.anzahl} '
        '${v.anzahl == 1 ? 'Preis' : 'Preisen'} bei ${v.laden}';
    if (v.vollstaendig) return '$grund.';
    return '$grund. ${v.ohnePreis.length} ohne Preis: '
        '${v.ohnePreis.take(3).join(', ')}'
        '${v.ohnePreis.length > 3 ? ' …' : ''}';
  }

  Future<List<Shop>?> _laeden() async {
    try {
      return await ShopService.loadAll();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
      return null;
    }
  }

  /// „Dieser Zettel kostet bei Aldi 34 €, bei Rewe 39 €."
  ///
  /// Die Preise holt es Posten für Posten aus dem Gedächtnis — das hängt
  /// an der Bezeichnung, nicht am Listeneintrag, und weiß deshalb auch
  /// etwas über Waren, die zum ersten Mal auf diesem Zettel stehen.
  Future<void> _preisvergleich() async {
    final offen = _positionen.where((p) => !p.erledigt).toList();
    if (offen.isEmpty) {
      _melde('Nichts Offenes zu rechnen.');
      return;
    }

    setState(() => _rechnet = true);
    final preise = <String, List<Warenpreis>>{};
    try {
      // Je Bezeichnung einmal: zwei Zeilen „Milch" sollen nicht zwei
      // Abfragen auslösen.
      for (final name in {for (final p in offen) p.name.trim().toLowerCase()}) {
        preise[name] = await EinkaufService.preise(name);
      }
    } finally {
      if (mounted) setState(() => _rechnet = false);
    }
    if (!mounted) return;

    final vergleich =
        Preisvergleich.rechne(positionen: offen, preise: preise);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _Vergleichsblatt(
        liste: widget.liste.name,
        vergleich: vergleich,
      ),
    );
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
          IconButton(
            icon: _rechnet
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.euro_outlined),
            tooltip: 'Was kostet der Zettel wo?',
            onPressed: _rechnet ? null : _preisvergleich,
          ),
          // Vor dem Wegräumen: wer erst räumt, kann nicht mehr buchen.
          if (erledigt.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.kitchen_outlined),
              tooltip: 'Abgehaktes in den Vorrat buchen',
              onPressed: () => _inDenVorrat(erledigt.length),
            ),
          // Nur mit Schreibrecht im Haushaltsbuch. Ein Knopf, der beim
          // Antippen „fehlt dir das Recht" sagt, ist kein Angebot.
          if (erledigt.isNotEmpty &&
              context.watch<PermissionProvider>().darf('finance:write'))
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Als Ausgabe buchen',
              onPressed: _rechnet ? null : _alsAusgabeBuchen,
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


/// Der Preisvergleich als Blatt von unten.
///
/// Zeigt nicht nur die Summen, sondern **worauf sie stehen**. Eine Zahl
/// ohne ihre Grundlage wäre hier gefährlich: wer „Aldi 12,40 €" liest und
/// nicht dazu, dass das nur neun von fünfzehn Posten sind, plant mit einer
/// Zahl, die es nicht gibt.
class _Vergleichsblatt extends StatelessWidget {
  final String liste;
  final Preisvergleich vergleich;

  const _Vergleichsblatt({required this.liste, required this.vergleich});

  String _euro(double betrag) => '${betrag.toStringAsFixed(2)} €'
      .replaceFirst('.', ',');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('„$liste" kostet', style: text.titleLarge),
          const SizedBox(height: 4),
          Text(
            vergleich.leer
                ? 'Dazu ist noch kein Preis gemerkt.'
                : 'Gerechnet auf ${vergleich.verglichen} von '
                    '${vergleich.gesamt} offenen Posten.',
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          for (var i = 0; i < vergleich.laeden.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    i == 0 ? Icons.savings_outlined : Icons.storefront_outlined,
                    size: 20,
                    color: i == 0 ? colors.primary : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      vergleich.laeden[i].laden,
                      style: i == 0
                          ? text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)
                          : text.titleMedium,
                    ),
                  ),
                  Text(
                    _euro(vergleich.laeden[i].summe),
                    style: (i == 0
                            ? text.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.primary)
                            : text.titleMedium)
                        ?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ],
              ),
            ),

          if (vergleich.ersparnis > 0.005) ...[
            const SizedBox(height: 4),
            Text(
              '${_euro(vergleich.ersparnis)} Unterschied.',
              style: text.bodyMedium?.copyWith(color: colors.primary),
            ),
          ],

          // Was nicht in die Rechnung einging, steht darunter — still
          // weglassen hiesse, eine Zahl größer aussehen zu lassen, als sie
          // gedeckt ist.
          if (vergleich.nichtUeberall.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Hinweis(
              symbol: Icons.compare_arrows_rounded,
              text: 'Nicht überall bekannt, deshalb draußen: '
                  '${vergleich.nichtUeberall.join(", ")}',
            ),
          ],
          if (vergleich.ohnePreis.isNotEmpty) ...[
            const SizedBox(height: 8),
            _Hinweis(
              symbol: Icons.help_outline_rounded,
              text: 'Noch kein Preis gemerkt: '
                  '${vergleich.ohnePreis.join(", ")}',
            ),
          ],
        ],
      ),
    );
  }
}

class _Hinweis extends StatelessWidget {
  final IconData symbol;
  final String text;

  const _Hinweis({required this.symbol, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(symbol, size: 16, color: colors.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// In welchem Laden eingekauft wurde.
///
/// Die Frage lässt sich nicht aus der Liste beantworten: ein Zettel sagt,
/// WAS gekauft wurde, nicht WO. Und der Preis hängt genau daran.
class _Ladenwahl extends StatelessWidget {
  final List<Shop> laeden;

  const _Ladenwahl({required this.laeden});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Wo war der Einkauf?',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final laden in laeden)
                    ListTile(
                      leading: const Icon(Icons.storefront_outlined),
                      title: Text(laden.name),
                      onTap: () => Navigator.pop(context, laden),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
}

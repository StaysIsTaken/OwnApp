import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/finanzen.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/dataservice/finanz_rechnung.dart';
import 'package:productivity/dataservice/finanz_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/tabs/finanzen/buchung_dialog.dart';
import 'package:productivity/tabs/finanzen/kassen_page.dart';

/// Das Haushaltsbuch, Monat für Monat.
///
/// Oben, was der Monat gebracht und gekostet hat; darunter die Buchungen,
/// nach Tagen gebündelt. Ein Monat ist der Takt, in dem Miete, Gehalt und
/// Abschläge laufen — eine Wochenansicht wäre hier so nützlich wie ein
/// Tageskalender für die Jahresplanung.
///
/// **Daueraufträge fehlen noch.** Was hier steht, ist von Hand gebucht;
/// die Vorschau auf Kommendes bringt ein späterer Schritt mit.
class FinanzenPage extends BasePage {
  const FinanzenPage({super.key}) : super(title: 'Haushaltsbuch');

  @override
  Widget buildBody(BuildContext context) => const _Monatsansicht();
}

class _Monatsansicht extends StatefulWidget {
  const _Monatsansicht();

  @override
  State<_Monatsansicht> createState() => _MonatsansichtState();
}

class _MonatsansichtState extends State<_Monatsansicht> {
  DateTime _monat = Finanzrechnung.monatsanfang(DateTime.now());

  List<Kasse> _kassen = [];
  List<Finanzkategorie> _kategorien = [];
  List<Buchung> _buchungen = [];
  Auswertung? _auswertung;

  /// Welche Kasse gezeigt wird — `null` heißt „alle sichtbaren".
  int? _kasse;

  bool _laedt = true;
  String? _fehler;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    setState(() {
      _laedt = true;
      _fehler = null;
    });

    final von = _monat;
    final bis = Finanzrechnung.monatsende(_monat);

    try {
      // Bewusst nacheinander und nicht in einem Future.wait: die
      // Auswertung braucht dieselben Rechte wie die Buchungen, und wenn
      // eines fehlt, soll die Meldung dazu kommen — nicht die von
      // irgendeinem der vier Aufrufe.
      final kassen = await FinanzService.kassen();
      final kategorien = await FinanzService.kategorien();
      final buchungen = await FinanzService.buchungen(
          kasse: _kasse, von: von, bis: bis);
      final auswertung = await FinanzService.auswertung(
          von: von, bis: bis, kasse: _kasse);

      if (!mounted) return;
      setState(() {
        _kassen = kassen;
        _kategorien = kategorien;
        _buchungen = buchungen;
        _auswertung = auswertung;
        _laedt = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _laedt = false;
        _fehler = ApiFehler.istVerboten(e)
            ? 'Für das Haushaltsbuch fehlt dir das Recht „finance:read".'
            : ApiFehler.text(e);
      });
    }
  }

  void _blaettern(int schritte) {
    setState(() => _monat = Finanzrechnung.monatVersetzt(_monat, schritte));
    _laden();
  }

  Future<void> _neu() async {
    if (_kassen.isEmpty) {
      await _keineKasse();
      return;
    }
    final eingabe = await BuchungDialog.zeige(
      context,
      kassen: _kassen,
      kategorien: _kategorien,
      kasseVorgabe: _kasse,
    );
    if (eingabe == null) return;
    try {
      await FinanzService.buchen(
        kasseId: eingabe.kasseId,
        tag: eingabe.tag,
        cents: eingabe.cents,
        titel: eingabe.titel,
        kategorieId: eingabe.kategorieId,
        notiz: eingabe.notiz,
      );
      // Auf den Monat springen, in dem die Buchung gelandet ist — sonst
      // tippt man ein Datum von letzter Woche ein und sieht nichts.
      final ziel = Finanzrechnung.monatsanfang(eingabe.tag);
      if (ziel != _monat) setState(() => _monat = ziel);
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _aendern(Buchung buchung) async {
    final eingabe = await BuchungDialog.zeige(
      context,
      kassen: _kassen,
      kategorien: _kategorien,
      vorhanden: buchung,
    );
    if (eingabe == null) return;
    try {
      await FinanzService.buchungAendern(
        buchung.id,
        tag: eingabe.tag,
        cents: eingabe.cents,
        titel: eingabe.titel,
        kategorieId: eingabe.kategorieId,
        notiz: eingabe.notiz,
      );
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _loeschen(Buchung buchung) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('„${buchung.titel}" löschen?'),
        content: Text('${Finanzrechnung.alsText(buchung.cents)} vom '
            '${Finanzrechnung.alsDatum(buchung.tag)}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Löschen')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FinanzService.buchungLoeschen(buchung.id);
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _keineKasse() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Noch keine Kasse'),
        content: const Text(
            'Buchungen brauchen eine Kasse — „Haushalt" zum Beispiel, oder '
            'ein Konto. Eine anlegen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Später')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Anlegen')),
        ],
      ),
    );
    if (ok == true && mounted) await _kassenOeffnen();
  }

  Future<void> _kassenOeffnen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KassenPage()),
    );
    if (mounted) await _laden();
  }

  void _melde(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (_laedt) return const Center(child: CircularProgressIndicator());
    if (_fehler != null) {
      return _Hinweis(text: _fehler!, onNochmal: _laden);
    }

    final gruppen = Finanzrechnung.nachTagen(_buchungen);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _laden,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            _Monatskopf(
              monat: _monat,
              auswertung: _auswertung,
              onZurueck: () => _blaettern(-1),
              onVor: () => _blaettern(1),
            ),
            const SizedBox(height: 12),
            if (_kassen.length > 1) _kassenwahl(),
            if (gruppen.isEmpty)
              _leer()
            else
              for (final gruppe in gruppen) ...[
                _Tageskopf(gruppe: gruppe),
                for (final b in gruppe.buchungen)
                  _Buchungszeile(
                    buchung: b,
                    kategorie: _kategorieZu(b.kategorieId),
                    kasse: _kassen.length > 1 ? _kasseZu(b.kasseId) : null,
                    onAendern: () => _aendern(b),
                    onLoeschen: () => _loeschen(b),
                  ),
              ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _neu,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buchung'),
      ),
    );
  }

  Finanzkategorie? _kategorieZu(int? id) {
    if (id == null) return null;
    for (final k in _kategorien) {
      if (k.id == id) return k;
    }
    return null;
  }

  Kasse? _kasseZu(int id) {
    for (final k in _kassen) {
      if (k.id == id) return k;
    }
    return null;
  }

  Widget _kassenwahl() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Alle'),
                selected: _kasse == null,
                onSelected: (_) {
                  setState(() => _kasse = null);
                  _laden();
                },
              ),
              for (final k in _kassen) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(k.name),
                  selected: _kasse == k.id,
                  onSelected: (_) {
                    setState(() => _kasse = k.id);
                    _laden();
                  },
                ),
              ],
            ],
          ),
        ),
      );

  Widget _leer() => Padding(
        padding: const EdgeInsets.fromLTRB(40, 60, 40, 0),
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              _kassen.isEmpty
                  ? 'Noch keine Kasse.\n'
                      'Unten rechts anfangen — „Haushalt" reicht für den Start.'
                  : 'Im ${Finanzrechnung.monatsname(_monat)} ist nichts '
                      'gebucht.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
          ],
        ),
      );
}

/// Monatswechsel und die drei Zahlen, für die man herkommt.
class _Monatskopf extends StatelessWidget {
  final DateTime monat;
  final Auswertung? auswertung;
  final VoidCallback onZurueck;
  final VoidCallback onVor;

  const _Monatskopf({
    required this.monat,
    required this.auswertung,
    required this.onZurueck,
    required this.onVor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final a = auswertung;
    final saldo = a?.saldoCents ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: onZurueck,
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: 'Monat zurück',
                ),
                Text(Finanzrechnung.monatsname(monat),
                    style: text.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                IconButton(
                  onPressed: onVor,
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: 'Monat vor',
                ),
              ],
            ),
            Text(
              Finanzrechnung.alsText(saldo),
              style: text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: saldo < 0 ? colors.error : Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Zahl(
                  label: 'Einnahmen',
                  wert: Finanzrechnung.nurBetrag(a?.einnahmenCents ?? 0),
                  farbe: Colors.green.shade700,
                ),
                _Zahl(
                  label: 'Ausgaben',
                  wert: Finanzrechnung.nurBetrag(a?.ausgabenCents ?? 0),
                  farbe: colors.error,
                ),
              ],
            ),
            if (a != null && a.jeKategorie.isNotEmpty) ...[
              const SizedBox(height: 16),
              _Verteilung(posten: a.jeKategorie),
            ],
          ],
        ),
      ),
    );
  }
}

class _Zahl extends StatelessWidget {
  final String label;
  final String wert;
  final Color farbe;

  const _Zahl({required this.label, required this.wert, required this.farbe});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(label,
            style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(wert,
            style: text.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600, color: farbe)),
      ],
    );
  }
}

/// Wohin das Geld ging — als Balken, nicht als Torte.
///
/// Auf einem Telefon sind fünf Kategorien nebeneinander lesbar, fünf
/// Tortenstücke mit Beschriftung nicht. Die richtige Torte steht später
/// als Kachel auf der Übersicht, wo sie Platz hat.
class _Verteilung extends StatelessWidget {
  final List<Kategoriesumme> posten;

  const _Verteilung({required this.posten});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final groesster = posten.first.cents;
    if (groesster <= 0) return const SizedBox.shrink();

    return Column(
      children: [
        for (final p in posten.take(5))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(p.name,
                      style: text.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: p.cents / groesster,
                      minHeight: 8,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      valueColor:
                          AlwaysStoppedAnimation(_farbe(p.color, context)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 78,
                  child: Text(Finanzrechnung.nurBetrag(p.cents),
                      style: text.bodySmall, textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Tageskopf extends StatelessWidget {
  final Tagesgruppe gruppe;

  const _Tageskopf({required this.gruppe});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(Finanzrechnung.alsDatum(gruppe.tag),
              style: text.labelLarge?.copyWith(color: colors.onSurfaceVariant)),
          Text(Finanzrechnung.alsText(gruppe.summeCents),
              style: text.labelLarge?.copyWith(color: colors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Buchungszeile extends StatelessWidget {
  final Buchung buchung;
  final Finanzkategorie? kategorie;
  final Kasse? kasse;
  final VoidCallback onAendern;
  final VoidCallback onLoeschen;

  const _Buchungszeile({
    required this.buchung,
    required this.kategorie,
    required this.kasse,
    required this.onAendern,
    required this.onLoeschen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final unterzeile = [
      if (kategorie != null) kategorie!.name,
      if (kasse != null) kasse!.name,
      if (buchung.notiz != null) buchung.notiz!,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAendern,
        onLongPress: onLoeschen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 36,
                decoration: BoxDecoration(
                  color: _farbe(kategorie?.color ?? '#94A3B8', context),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(buchung.titel,
                              style: text.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        // Dieselbe Markierung wie bei Serienterminen im
                        // Kalender – wer sie dort gelernt hat, versteht
                        // sie hier ohne Erklärung.
                        if (buchung.ausSerie) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.repeat_rounded,
                              size: 14, color: colors.onSurfaceVariant),
                        ],
                      ],
                    ),
                    if (unterzeile.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(unterzeile,
                          style: text.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Finanzrechnung.alsText(buchung.cents),
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: buchung.istAusgabe
                      ? colors.onSurface
                      : Colors.green.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hinweis extends StatelessWidget {
  final String text;
  final VoidCallback onNochmal;

  const _Hinweis({required this.text, required this.onNochmal});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(text, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed: onNochmal, child: const Text('Nochmal')),
            ],
          ),
        ),
      );
}

/// „#22C55E" → Farbe. Fällt auf die Umrissfarbe zurück, statt zu werfen.
Color _farbe(String hex, BuildContext context) {
  final sauber = hex.replaceAll('#', '');
  final wert = int.tryParse(sauber, radix: 16);
  if (wert == null || sauber.length != 6) {
    return Theme.of(context).colorScheme.outline;
  }
  return Color(0xFF000000 | wert);
}

import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/finanzen.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/dataservice/finanz_rechnung.dart';
import 'package:productivity/dataservice/finanz_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/tabs/finanzen/serie_dialog.dart';
import 'package:productivity/tabs/finanzen/stufe_dialog.dart';

/// Daueraufträge: Miete, Strom, Gehalt, das Zeitungsabo.
///
/// Der Betrag steht nicht am Dauerauftrag, sondern in einer **Staffel**
/// mit Stichtagen. Ändert sich der Abschlag im April, bekommt er eine
/// neue Stufe — der Januar bleibt bei seinem alten Wert, und „was habe
/// ich letztes Jahr für Strom gezahlt" beantwortet sich weiter richtig.
class SerienPage extends BasePage {
  const SerienPage({super.key}) : super(title: 'Daueraufträge');

  @override
  Widget buildBody(BuildContext context) => const _Serien();
}

class _Serien extends StatefulWidget {
  const _Serien();

  @override
  State<_Serien> createState() => _SerienState();
}

class _SerienState extends State<_Serien> {
  List<Dauerauftrag> _serien = [];
  List<Kasse> _kassen = [];
  List<Finanzkategorie> _kategorien = [];
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
    try {
      final kassen = await FinanzService.kassen();
      final kategorien = await FinanzService.kategorien();
      final serien = await FinanzService.serien();
      if (!mounted) return;
      setState(() {
        _kassen = kassen;
        _kategorien = kategorien;
        _serien = serien;
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

  Future<void> _neu() async {
    if (_kassen.isEmpty) {
      _melde('Erst eine Kasse anlegen — ohne die kann nichts buchen.');
      return;
    }
    final eingabe = await SerieDialog.zeige(
      context,
      kassen: _kassen,
      kategorien: _kategorien,
    );
    if (eingabe == null) return;
    try {
      await FinanzService.serieAnlegen(
        kasseId: eingabe.kasseId,
        titel: eingabe.titel,
        start: eingabe.start,
        cents: eingabe.cents,
        freq: eingabe.freq,
        intervall: eingabe.intervall,
        wochentage: eingabe.wochentage,
        monatstag: eingabe.monatstag,
        ende: eingabe.ende,
        kategorieId: eingabe.kategorieId,
        notiz: eingabe.notiz,
      );
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _bearbeiten(Dauerauftrag serie) async {
    final eingabe = await SerieDialog.zeige(
      context,
      kassen: _kassen,
      kategorien: _kategorien,
      vorhanden: serie,
    );
    if (eingabe == null) return;
    try {
      await FinanzService.serieAendern(
        serie.id,
        titel: eingabe.titel,
        freq: eingabe.freq,
        intervall: eingabe.intervall,
        wochentage: eingabe.wochentage,
        monatstag: eingabe.monatstag,
        start: eingabe.start,
        ende: eingabe.ende,
        kategorieId: eingabe.kategorieId,
        notiz: eingabe.notiz,
      );
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _aussetzen(Dauerauftrag serie) async {
    try {
      await FinanzService.serieAendern(serie.id, aktiv: !serie.aktiv);
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _loeschen(Dauerauftrag serie) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('„${serie.titel}" löschen?'),
        content: const Text(
            'Die bereits gebuchten Zeilen bleiben stehen — nur die Regel '
            'geht.\n\n'
            'Wer nur aufhören will zu buchen, setzt den Dauerauftrag '
            'besser aus: dann bleibt nachvollziehbar, woher die alten '
            'Buchungen kommen.'),
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
      await FinanzService.serieLoeschen(serie.id);
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _stufeSetzen(Dauerauftrag serie) async {
    final eingabe = await StufeDialog.zeige(context, serie: serie);
    if (eingabe == null) return;
    try {
      await FinanzService.stufeSetzen(
        serie.id,
        gueltigAb: eingabe.gueltigAb,
        cents: eingabe.cents,
        notiz: eingabe.notiz,
      );
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _stufeLoeschen(Dauerauftrag serie, Betragsstufe stufe) async {
    try {
      await FinanzService.stufeLoeschen(serie.id, stufe.id);
      await _laden();
    } catch (e) {
      // Der Server lässt die letzte Stufe nicht löschen und sagt auch
      // warum — die Meldung soll ankommen.
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  void _melde(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (_laedt) return const Center(child: CircularProgressIndicator());
    if (_fehler != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(_fehler!, textAlign: TextAlign.center),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _laden,
        child: _serien.isEmpty
            ? _leer()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                itemCount: _serien.length,
                itemBuilder: (_, i) => _Karte(
                  serie: _serien[i],
                  kasse: _kasseZu(_serien[i].kasseId),
                  kategorie: _kategorieZu(_serien[i].kategorieId),
                  onBearbeiten: () => _bearbeiten(_serien[i]),
                  onAussetzen: () => _aussetzen(_serien[i]),
                  onLoeschen: () => _loeschen(_serien[i]),
                  onStufe: () => _stufeSetzen(_serien[i]),
                  onStufeLoeschen: (s) => _stufeLoeschen(_serien[i], s),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _neu,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Dauerauftrag'),
      ),
    );
  }

  Kasse? _kasseZu(int id) {
    for (final k in _kassen) {
      if (k.id == id) return k;
    }
    return null;
  }

  Finanzkategorie? _kategorieZu(int? id) {
    if (id == null) return null;
    for (final k in _kategorien) {
      if (k.id == id) return k;
    }
    return null;
  }

  Widget _leer() => ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.repeat_rounded,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Noch kein Dauerauftrag.\n'
              'Miete, Strom, Gehalt — was jeden Monat gleich läuft, muss '
              'man nur einmal eintragen.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
          ),
        ],
      );
}

class _Karte extends StatelessWidget {
  final Dauerauftrag serie;
  final Kasse? kasse;
  final Finanzkategorie? kategorie;
  final VoidCallback onBearbeiten;
  final VoidCallback onAussetzen;
  final VoidCallback onLoeschen;
  final VoidCallback onStufe;
  final void Function(Betragsstufe) onStufeLoeschen;

  const _Karte({
    required this.serie,
    required this.kasse,
    required this.kategorie,
    required this.onBearbeiten,
    required this.onAussetzen,
    required this.onLoeschen,
    required this.onStufe,
    required this.onStufeLoeschen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final betrag = serie.aktuellerBetragCents;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        // Ausgesetzte blassen ab, verschwinden aber nicht: sie sollen
        // wiederfindbar bleiben.
        opacity: serie.aktiv ? 1 : 0.55,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Icon(
            serie.aktiv ? Icons.repeat_rounded : Icons.pause_circle_outline,
            color: serie.aktiv ? colors.primary : colors.outline,
          ),
          title: Text(serie.titel,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text(
            [
              Finanzrechnung.takt(serie),
              if (kategorie != null) kategorie!.name,
              if (kasse != null) kasse!.name,
              if (!serie.aktiv) 'ausgesetzt',
            ].join(' · '),
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                betrag == null ? '—' : Finanzrechnung.alsText(betrag),
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (serie.naechsteFaelligkeit != null && serie.aktiv)
                Text('ab ${Finanzrechnung.alsDatum(serie.naechsteFaelligkeit!)}',
                    style: text.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant)),
            ],
          ),
          children: [
            _Staffel(
              serie: serie,
              onStufe: onStufe,
              onStufeLoeschen: onStufeLoeschen,
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onAussetzen,
                    icon: Icon(serie.aktiv
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded),
                    label: Text(serie.aktiv ? 'Aussetzen' : 'Fortsetzen'),
                  ),
                  TextButton(
                      onPressed: onBearbeiten, child: const Text('Ändern')),
                  TextButton(
                      onPressed: onLoeschen, child: const Text('Löschen')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Die Betragsstaffel — der Kern des Entwurfs, sichtbar gemacht.
class _Staffel extends StatelessWidget {
  final Dauerauftrag serie;
  final VoidCallback onStufe;
  final void Function(Betragsstufe) onStufeLoeschen;

  const _Staffel({
    required this.serie,
    required this.onStufe,
    required this.onStufeLoeschen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final heute = DateTime.now();
    final stufen = [...serie.staffel]
      ..sort((a, b) => a.gueltigAb.compareTo(b.gueltigAb));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Beträge',
                  style: text.labelLarge
                      ?.copyWith(color: colors.onSurfaceVariant)),
              TextButton.icon(
                onPressed: onStufe,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Ab Stichtag'),
              ),
            ],
          ),
        ),
        for (final stufe in stufen)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(Finanzrechnung.nurBetrag(stufe.cents)),
            subtitle: Text('ab ${Finanzrechnung.alsDatum(stufe.gueltigAb)}'
                '${stufe.notiz == null ? '' : ' · ${stufe.notiz}'}'),
            // Was heute gilt, ist die Auskunft, für die man aufklappt.
            leading: Icon(
              stufe.gueltigAb.isAfter(heute)
                  ? Icons.schedule_rounded
                  : Icons.check_circle_outline_rounded,
              size: 18,
              color: stufe.gueltigAb.isAfter(heute)
                  ? colors.outline
                  : colors.primary,
            ),
            trailing: stufen.length > 1
                ? IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    tooltip: 'Stufe entfernen',
                    onPressed: () => onStufeLoeschen(stufe),
                  )
                // Die letzte Stufe lässt der Server nicht löschen. Den
                // Knopf trotzdem anzubieten hiesse, eine Absage
                // anzukündigen.
                : null,
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/haushalt.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/dataservice/finanz_rechnung.dart';
import 'package:productivity/dataservice/haushalt_service.dart';
import 'package:productivity/dataservice/haushalt_sicht.dart';
import 'package:productivity/main.dart';
import 'package:productivity/provider/user_provider.dart';
import 'package:productivity/tabs/haushalt/einladung_dialog.dart';
import 'package:provider/provider.dart';

/// Was der Haushalt im Monat gebracht und gekostet hat.
///
/// **Zusammengerechnet über die Mitglieder — aber nur so weit, wie jedes
/// einzelne es erlaubt.** Wer auf „Nichts" steht, fehlt in der Summe, und
/// genau das steht unter der Zahl: „2 von 3 Mitgliedern rechnen mit."
/// Ohne diesen Satz hält jemand eine unvollständige Summe für die
/// Wahrheit — derselbe Gedanke wie bei `ohne_preis` und `ohne_zutat`.
///
/// Die eigene Stufe lässt sich von hier aus ändern. Das ist der Ort, an
/// dem man merkt, dass man selbst nicht mitrechnet.
class HaushaltFinanzenPage extends BasePage {
  const HaushaltFinanzenPage({super.key})
      : super(title: 'Haushalt — Finanzen');

  @override
  Widget buildBody(BuildContext context) => const _Uebersicht();
}

class _Uebersicht extends StatefulWidget {
  const _Uebersicht();

  @override
  State<_Uebersicht> createState() => _UebersichtState();
}

class _UebersichtState extends State<_Uebersicht> {
  DateTime _monat = Finanzrechnung.monatsanfang(DateTime.now());
  HaushaltsFinanzen? _finanzen;
  bool _laedt = true;
  String? _fehler;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  String get _ichId =>
      Provider.of<UserProvider>(context, listen: false).user?.id ?? '';

  Future<void> _laden() async {
    setState(() {
      _laedt = true;
      _fehler = null;
    });
    try {
      final daten = await HaushaltService.finanzen(
        Finanzrechnung.monatsanfang(_monat),
        Finanzrechnung.monatsende(_monat),
      );
      if (!mounted) return;
      setState(() {
        _finanzen = daten;
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
    setState(() {
      _monat = Finanzrechnung.monatVersetzt(_monat, schritte);
      _laedt = true;
    });
    _laden();
  }

  /// Die eigene Stufe ändern — von genau der Seite aus, auf der man
  /// merkt, dass man nicht mitrechnet.
  Future<void> _stufeAendern(MitgliedsFinanzen ich) async {
    final stufe =
        await FinanzsichtDialog.zeige(context, aktuell: ich.finanzsicht);
    if (stufe == null) return;
    try {
      await HaushaltService.finanzsicht(stufe);
      await _laden();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiFehler.text(e))));
      }
    }
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

    final f = _finanzen;
    if (f == null) {
      return const Center(child: Text('Du bist in keinem Haushalt.'));
    }

    final ich = _ichId;

    return RefreshIndicator(
      onRefresh: _laden,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
        children: [
          _Monatskopf(
            monat: _monat,
            finanzen: f,
            onZurueck: () => _blaettern(-1),
            onVor: () => _blaettern(1),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Text(
              'MITGLIEDER',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          for (final m in f.mitglieder)
            _Mitgliedszeile(
              mitglied: m,
              ichSelbst: m.userId == ich,
              onStufe: m.userId == ich ? () => _stufeAendern(m) : null,
            ),
        ],
      ),
    );
  }
}

/// Monatswechsel, die Summe — und der Satz, wer fehlt.
class _Monatskopf extends StatelessWidget {
  final DateTime monat;
  final HaushaltsFinanzen finanzen;
  final VoidCallback onZurueck;
  final VoidCallback onVor;

  const _Monatskopf({
    required this.monat,
    required this.finanzen,
    required this.onZurueck,
    required this.onVor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final saldo = finanzen.saldoCents;
    final hinweis = Haushaltssicht.mitrechnenSatz(finanzen);

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
                  wert: Finanzrechnung.nurBetrag(finanzen.einnahmenCents),
                  farbe: Colors.green.shade700,
                ),
                _Zahl(
                  label: 'Ausgaben',
                  wert: Finanzrechnung.nurBetrag(finanzen.ausgabenCents),
                  farbe: colors.error,
                ),
              ],
            ),

            // Der Satz, ohne den die Summe vollständig aussieht.
            if (hinweis.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 18, color: colors.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        hinweis,
                        style: text.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
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
                ?.copyWith(fontWeight: FontWeight.w700, color: farbe)),
      ],
    );
  }
}

/// Eine Zeile je Mitglied — mit dem, was es preisgibt, oder ohne.
class _Mitgliedszeile extends StatelessWidget {
  final MitgliedsFinanzen mitglied;
  final bool ichSelbst;
  final VoidCallback? onStufe;

  const _Mitgliedszeile({
    required this.mitglied,
    required this.ichSelbst,
    this.onStufe,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          mitglied.rechnetMit
              ? Icons.person_rounded
              : Icons.visibility_off_outlined,
          color: mitglied.rechnetMit ? colors.primary : colors.outline,
        ),
        title: Text(ichSelbst ? '${mitglied.name} (du)' : mitglied.name),
        // Die Stufe steht dabei: die anderen sollen wissen, WARUM bei
        // jemandem keine Zahl steht.
        subtitle: Text(
          mitglied.rechnetMit
              ? mitglied.finanzsicht.titel
              : 'Zeigt seine Zahlen nicht',
          style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        trailing: mitglied.rechnetMit
            ? Text(
                Finanzrechnung.alsText(mitglied.saldoCents ?? 0),
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: (mitglied.saldoCents ?? 0) < 0 ? colors.error : null,
                ),
              )
            // Ein Gedankenstrich und keine 0: „gibt nichts preis" ist
            // nicht dasselbe wie „hat null Euro".
            : Text('—',
                style: text.titleSmall?.copyWith(color: colors.outline)),
        onTap: onStufe,
      ),
    );
  }
}

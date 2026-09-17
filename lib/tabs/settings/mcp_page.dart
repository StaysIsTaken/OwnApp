import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:productivity/dataclasses/mcp_zugang.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/dataservice/api_client.dart';
import 'package:productivity/dataservice/mcp_anleitung.dart';
import 'package:productivity/dataservice/mcp_baum.dart';
import 'package:productivity/dataservice/mcp_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/provider/haushalt_provider.dart';
import 'package:productivity/utils/link_oeffnen.dart';
import 'package:productivity/utils/snack.dart';
import 'package:provider/provider.dart';

/// Der Zugang für fremde Assistenten — ein Baum, der bei „alles aus"
/// anfängt.
///
/// Jede Ebene klappt erst auf, wenn die darüber an ist: Hauptschalter →
/// Bereiche → Schreiben. Der Haushalt ist ein eigener Ast mit derselben
/// Regel.
///
/// **Was angeht, geht mit allem darunter aus an.** Deshalb setzt der
/// Server beim Ausschalten den Unterbaum zurück, statt sich die alten
/// Haken zu merken — sonst wäre das Schreiben still wieder da, wenn man
/// einen Bereich Monate später erneut anschaltet.
class McpPage extends BasePage {
  const McpPage({super.key}) : super(title: 'Assistent-Zugang');

  @override
  Widget buildBody(BuildContext context) => const _Mcp();
}

class _Mcp extends StatefulWidget {
  const _Mcp();

  @override
  State<_Mcp> createState() => _McpState();
}

class _McpState extends State<_Mcp> {
  McpZugang _zugang = const McpZugang();
  bool _laedt = true;
  bool _arbeitet = false;
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
      final zugang = await McpService.lesen();
      if (!mounted) return;
      setState(() {
        _zugang = zugang;
        _laedt = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fehler = ApiFehler.text(e);
        _laedt = false;
      });
    }
  }

  Future<void> _schalte(String feld, bool an) async {
    if (_arbeitet) return;
    setState(() => _arbeitet = true);
    try {
      final zugang = await McpService.schalte(feld, an);
      if (!mounted) return;
      setState(() => _zugang = zugang);
    } catch (e) {
      if (mounted) showErrorSnack(ApiFehler.text(e));
    } finally {
      if (mounted) setState(() => _arbeitet = false);
    }
  }

  /// Schlüssel erzeugen oder erneuern.
  ///
  /// Beim Erneuern wird vorher gefragt, und zwar deutlich: der alte hört
  /// **sofort** auf zu gelten, ohne Übergangsfenster. Ein Fenster wäre
  /// keine Sperre, sondern eine Bitte — und wer hier erneuert, hat
  /// meistens einen Grund dafür.
  Future<void> _schluessel() async {
    if (_zugang.hatSchluessel) {
      final weiter = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Neuen Schlüssel erzeugen?'),
          content: const Text(
            'Der bisherige Schlüssel hört sofort auf zu gelten. Du musst '
            'den neuen überall eintragen, wo der alte steht.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Erneuern'),
            ),
          ],
        ),
      );
      if (weiter != true || !mounted) return;
    }

    try {
      final neu = await McpService.schluesselNeu();
      if (!mounted) return;
      await _zeigeSchluessel(neu);
      await _laden();
    } catch (e) {
      if (mounted) showErrorSnack(ApiFehler.text(e));
    }
  }

  /// Die einzige Gelegenheit, den Schlüssel zu sehen.
  ///
  /// Gespeichert ist nur sein Hash — nachschlagen geht also nicht, und
  /// das ist der Sinn: ein Datenbankabzug enthält ihn damit nicht, und
  /// beim Ausrollen entsteht bei jedem Mal einer.
  Future<void> _zeigeSchluessel(McpSchluessel neu) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Dein Schlüssel'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dieser Schlüssel wird nicht noch einmal angezeigt. '
                  'Kopiere ihn jetzt.',
                ),
                const SizedBox(height: 12),
                SelectableText(
                  neu.schluessel,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                const Divider(height: 28),
                // Der einzige Moment, in dem der Befehl komplett
                // dasteht. Auf der Seite selbst steht danach ein
                // Platzhalter -- wir haben den Schlüssel dann nicht mehr.
                Text('Für Claude Code, fertig zum Einfügen:',
                    style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 6),
                SelectableText(
                  McpAnleitung.claudeCodeBefehl(
                    McpAnleitung.adresse(ApiClient.baseUrl, neu.slug),
                    schluessel: neu.schluessel,
                  ),
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 12),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Befehl kopieren'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                      text: McpAnleitung.claudeCodeBefehl(
                        McpAnleitung.adresse(ApiClient.baseUrl, neu.slug),
                        schluessel: neu.schluessel,
                      ),
                    ));
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Befehl kopiert')),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: neu.schluessel));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Schlüssel kopiert')),
                );
              },
              child: const Text('Kopieren'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fertig'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_laedt) return const Center(child: CircularProgressIndicator());
    if (_fehler != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_fehler!, textAlign: TextAlign.center),
      ));
    }

    final imHaushalt = context.watch<HaushaltProvider>().haushalt != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _Erklaerung(),
        const SizedBox(height: 12),

        Card(
          child: SwitchListTile(
            title: const Text('Assistent-Zugang'),
            subtitle: Text(_zugang.an
                ? 'An — gibt heraus, was unten angehakt ist.'
                : 'Aus. Nichts verlässt diesen Server.'),
            value: _zugang.an,
            onChanged: _arbeitet ? null : (an) => _schalte('mcp_an', an),
          ),
        ),

        // Ebene 2: die Bereiche. Erst sichtbar, wenn der Stamm an ist —
        // sonst stünde hier eine Liste von Schaltern ohne Wirkung.
        if (McpBaum.zeigtBereiche(_zugang)) ...[
          const SizedBox(height: 16),
          if (_zugang.hatSchluessel) _Zugangsdaten(zugang: _zugang),
          if (!_zugang.hatSchluessel)
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const ListTile(
                leading: Icon(Icons.key_off_outlined),
                title: Text('Noch kein Schlüssel'),
                subtitle: Text(
                  'Ohne Schlüssel ist der Zugang eine Adresse ohne Tür.',
                ),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _schluessel,
            icon: const Icon(Icons.key),
            label: Text(_zugang.hatSchluessel
                ? 'Neuen Schlüssel erzeugen'
                : 'Schlüssel erzeugen'),
          ),

          if (_zugang.hatSchluessel) ...[
            const SizedBox(height: 16),
            const _Ueberschrift('Einrichten'),
            const _Einrichten(),
          ],

          const SizedBox(height: 16),
          const _Ueberschrift('Meine Daten'),
          for (final bereich in McpBaum.bereiche)
            _BereichKachel(
              bereich: bereich,
              zugang: _zugang,
              arbeitet: _arbeitet,
              schalte: _schalte,
            ),
        ],

        // Ebene 2b: der Haushalt, wieder mit allem darunter aus.
        if (McpBaum.zeigtHaushalt(_zugang, imHaushalt: imHaushalt)) ...[
          const SizedBox(height: 16),
          const _Ueberschrift('Unsere Daten'),
          Card(
            child: SwitchListTile(
              title: const Text('Haushalt einbeziehen'),
              subtitle: const Text(
                'Auch dann geht nur heraus, was die Mitglieder selbst '
                'freigegeben haben.',
              ),
              value: _zugang.ist('mcp_haushalt'),
              onChanged:
                  _arbeitet ? null : (an) => _schalte('mcp_haushalt', an),
            ),
          ),
          if (McpBaum.zeigtHaushaltsbereiche(_zugang, imHaushalt: imHaushalt))
            for (final bereich in McpBaum.haushaltsbereiche)
              _BereichKachel(
                bereich: bereich,
                zugang: _zugang,
                arbeitet: _arbeitet,
                schalte: _schalte,
              ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

class _Erklaerung extends StatelessWidget {
  const _Erklaerung();

  @override
  Widget build(BuildContext context) => Text(
        'Ein Assistent außerhalb dieser App kann hiermit deine Daten lesen '
        '— aber nur die Bereiche, die du anhakst, und nur so weit, wie '
        'deine Rolle es ohnehin erlaubt. Gelöscht wird über diesen Weg '
        'nie.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
}

class _Ueberschrift extends StatelessWidget {
  final String text;
  const _Ueberschrift(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
      );
}

class _Zugangsdaten extends StatelessWidget {
  final McpZugang zugang;
  const _Zugangsdaten({required this.zugang});

  @override
  Widget build(BuildContext context) {
    final benutzt = zugang.zuletztBenutzt;
    final adresse = McpAnleitung.adresse(ApiClient.baseUrl, zugang.slug);
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Adresse'),
            // Vollständig, nicht `/mcp/…`: ein Client bekommt nur diesen
            // einen String zu sehen.
            subtitle: SelectableText(adresse),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Kopieren',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: adresse));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Adresse kopiert')),
                );
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: Text(zugang.schluesselAnfang ?? ''),
            // „Zuletzt benutzt" ist nicht Zierde: daran sieht man, dass
            // jemand den Zugang benutzt, den man selbst gerade nicht
            // benutzt.
            subtitle: Text(benutzt == null
                ? 'Noch nie benutzt'
                : 'Zuletzt benutzt: ${_kurz(benutzt)}'),
          ),
        ],
      ),
    );
  }

  static String _kurz(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}. '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Ein Bereich mit seiner Schreiben-Ebene darunter.
class _BereichKachel extends StatelessWidget {
  final McpBereich bereich;
  final McpZugang zugang;
  final bool arbeitet;
  final Future<void> Function(String, bool) schalte;

  const _BereichKachel({
    required this.bereich,
    required this.zugang,
    required this.arbeitet,
    required this.schalte,
  });

  @override
  Widget build(BuildContext context) {
    final an = zugang.ist(bereich.feld);
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: Text(bereich.name),
            subtitle: Text(bereich.erklaerung),
            value: an,
            onChanged: arbeitet ? null : (wert) => schalte(bereich.feld, wert),
          ),
          // Ebene 3. Nur sichtbar, wenn der Bereich an ist — und beim
          // Ausschalten setzt der Server sie mit zurück.
          if (McpBaum.zeigtSchreiben(zugang, bereich.feld))
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: SwitchListTile(
                dense: true,
                title: const Text('Auch schreiben'),
                subtitle: const Text('Anlegen und ändern. Nie löschen.'),
                value: zugang.ist(bereich.schreibfeld),
                onChanged: arbeitet
                    ? null
                    : (wert) => schalte(bereich.schreibfeld, wert),
              ),
            ),
        ],
      ),
    );
  }
}


/// „Wie trage ich das ein?" — je Assistent ein aufklappbarer Eintrag.
///
/// Der Stand der Clients ist der Grund für diesen Abschnitt: **nur
/// Claude Code nimmt heute einen eigenen Schlüssel entgegen.** Alle
/// anderen haben ein Feld für die Adresse und sonst nichts, und ohne
/// Schlüssel antwortet der Zugang mit 404 — das sieht wie ein Fehler
/// dieser App aus und ist keiner. Deshalb steht es hier.
class _Einrichten extends StatelessWidget {
  const _Einrichten();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        children: [
          for (final client in McpAnleitung.clients)
            ExpansionTile(
              leading: Icon(
                client.nimmtSchluessel
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
                color: client.nimmtSchluessel
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
              title: Text(client.name),
              subtitle: Text(client.nimmtSchluessel
                  ? 'Nimmt den Schlüssel entgegen'
                  : 'Kein Feld für den Schlüssel'),
              childrenPadding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (client.hinweis != null) ...[
                  Text(client.hinweis!,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 10),
                ],
                for (var i = 0; i < client.schritte.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${i + 1}.  '),
                        Expanded(child: Text(client.schritte[i])),
                      ],
                    ),
                  ),
                if (client.nimmtSchluessel) ...[
                  const SizedBox(height: 8),
                  _Befehl(),
                ],
                const SizedBox(height: 8),
                _Doku(url: client.doku),
              ],
            ),
        ],
      ),
    );
  }
}

/// Der Befehl mit Platzhalter — den Schlüssel selbst haben wir nicht mehr.
class _Befehl extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final befehl = McpAnleitung.claudeCodeBefehl(
        McpAnleitung.adresse(ApiClient.baseUrl, _slug(context)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            befehl,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Kopieren'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: befehl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Befehl kopiert')),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'DEIN_SCHLUESSEL ersetzen — oder gleich beim Erzeugen '
                'kopieren, dort steht er schon drin.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String? _slug(BuildContext context) =>
      context.findAncestorStateOfType<_McpState>()?._zugang.slug;
}

/// Die Anleitung des Herstellers — antippen öffnet sie im Browser.
///
/// Der Kopier-Knopf bleibt daneben: auf dem Küchentablet im Kioskmodus
/// gibt es womöglich gar keinen Browser, und dann ist die Adresse in der
/// Zwischenablage mehr wert als ein Knopf, der nichts tut.
class _Doku extends StatelessWidget {
  final String url;
  const _Doku({required this.url});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: InkWell(
            onTap: () => linkOeffnen(context, url),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.open_in_new, size: 16, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Anleitung des Anbieters',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.primary,
                            decoration: TextDecoration.underline,
                            decorationColor: colors.primary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 16),
          tooltip: 'Link kopieren',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Link kopiert')),
            );
          },
        ),
      ],
    );
  }
}

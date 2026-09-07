import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/einkauf.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/dataservice/einkauf_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/tabs/einkauf/einkaufsliste_page.dart';
import 'package:productivity/widgets/color_picker_dialog.dart';

/// Übersicht über die Einkaufslisten.
///
/// Früher gab es *die* Einkaufsliste. Jetzt so viele, wie man braucht —
/// Wochenkauf und Baumarkt gehören nicht auf denselben Zettel.
///
/// Fürs Telefon gebaut: eine Karte je Liste, groß genug für den Daumen,
/// und die Zahl der offenen Posten direkt darauf. Wer einkaufen geht,
/// tippt einmal und ist drin.
class EinkaufslistenPage extends BasePage {
  const EinkaufslistenPage({super.key}) : super(title: 'Einkaufslisten');

  @override
  Widget buildBody(BuildContext context) => const _Uebersicht();
}

class _Uebersicht extends StatefulWidget {
  const _Uebersicht();

  @override
  State<_Uebersicht> createState() => _UebersichtState();
}

class _UebersichtState extends State<_Uebersicht> {
  List<Einkaufsliste> _listen = [];
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
      final listen = await EinkaufService.listen();
      if (!mounted) return;
      setState(() {
        _listen = listen;
        _laedt = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _laedt = false;
        _fehler = ApiFehler.istVerboten(e)
            ? 'Für Einkaufslisten fehlt dir das Recht „shopping:read".'
            : ApiFehler.text(e);
      });
    }
  }

  Future<void> _anlegen() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NameDialog(titel: 'Neue Liste'),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      final liste = await EinkaufService.listeAnlegen(name.trim());
      if (!mounted) return;
      await _oeffnen(liste);
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _oeffnen(Einkaufsliste liste) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EinkaufslistePage(liste: liste)),
    );
    if (mounted) _laden();
  }

  Future<void> _umbenennen(Einkaufsliste liste) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(titel: 'Umbenennen', vorgabe: liste.name),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await EinkaufService.listeAendern(liste.id, name: name.trim());
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _farbe(Einkaufsliste liste) async {
    final farbe = await ColorPickerDialog.show(context, liste.color);
    if (farbe == null) return;
    try {
      await EinkaufService.listeAendern(liste.id, color: farbe);
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _loeschen(Einkaufsliste liste) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('„${liste.name}" löschen?'),
        content: Text(liste.offen + liste.erledigt == 0
            ? 'Die Liste ist leer.'
            : 'Die ${liste.offen + liste.erledigt} Positionen darauf gehen '
                'mit. Preise bleiben — die hängen an der Ware, nicht an '
                'der Liste.'),
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
      await EinkaufService.listeLoeschen(liste.id);
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
    if (_laedt) return const Center(child: CircularProgressIndicator());
    if (_fehler != null) return _Hinweis(text: _fehler!, onNochmal: _laden);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _laden,
        child: _listen.isEmpty
            ? _leer()
            : ListView.builder(
                // Unten Luft für den Knopf – sonst verdeckt er die letzte
                // Liste, und die erreicht man dann nie.
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                itemCount: _listen.length,
                itemBuilder: (_, i) => _Karte(
                  liste: _listen[i],
                  onOeffnen: () => _oeffnen(_listen[i]),
                  onUmbenennen: () => _umbenennen(_listen[i]),
                  onFarbe: () => _farbe(_listen[i]),
                  onLoeschen: () => _loeschen(_listen[i]),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _anlegen,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Liste'),
      ),
    );
  }

  Widget _leer() => ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.shopping_cart_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Noch keine Liste.\n'
              'Unten rechts eine anlegen — zum Beispiel „Wocheneinkauf".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
          ),
        ],
      );
}

class _Karte extends StatelessWidget {
  final Einkaufsliste liste;
  final VoidCallback onOeffnen;
  final VoidCallback onUmbenennen;
  final VoidCallback onFarbe;
  final VoidCallback onLoeschen;

  const _Karte({
    required this.liste,
    required this.onOeffnen,
    required this.onUmbenennen,
    required this.onFarbe,
    required this.onLoeschen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOeffnen,
        child: Padding(
          // Grosszuegig: das wird unterwegs mit einer Hand bedient.
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 44,
                decoration: BoxDecoration(
                  color: _farbe(liste.color),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(liste.name,
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      _untertitel(),
                      style: text.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // Die Zahl der offenen Posten ist die Auskunft, die man beim
              // Vorbeigehen braucht.
              if (liste.offen > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('${liste.offen}',
                      style: text.titleSmall?.copyWith(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.bold)),
                ),
              PopupMenuButton<String>(
                onSelected: (wahl) => switch (wahl) {
                  'umbenennen' => onUmbenennen(),
                  'farbe' => onFarbe(),
                  _ => onLoeschen(),
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'umbenennen', child: Text('Umbenennen')),
                  PopupMenuItem(value: 'farbe', child: Text('Farbe')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'loeschen', child: Text('Löschen')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _untertitel() {
    if (liste.offen == 0 && liste.erledigt == 0) return 'leer';
    final teile = <String>[];
    if (liste.offen > 0) {
      teile.add('${liste.offen} offen');
    } else {
      teile.add('alles erledigt');
    }
    if (liste.erledigt > 0) teile.add('${liste.erledigt} abgehakt');
    if (liste.memberIds.isNotEmpty) {
      teile.add('geteilt mit ${liste.memberIds.length}');
    }
    return teile.join(' · ');
  }
}

Color _farbe(String hex) {
  final roh = hex.replaceFirst('#', '');
  final wert = int.tryParse(roh, radix: 16);
  return wert == null ? const Color(0xFF3B82F6) : Color(0xFF000000 | wert);
}

class _NameDialog extends StatefulWidget {
  final String titel;
  final String? vorgabe;

  const _NameDialog({required this.titel, this.vorgabe});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _feld =
      TextEditingController(text: widget.vorgabe ?? '');

  @override
  void dispose() {
    _feld.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.titel),
        content: TextField(
          controller: _feld,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'z. B. Wocheneinkauf',
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(context, _feld.text),
              child: const Text('Speichern')),
        ],
      );
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
              Icon(Icons.error_outline,
                  size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(text, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(onPressed: onNochmal, child: const Text('Nochmal')),
            ],
          ),
        ),
      );
}

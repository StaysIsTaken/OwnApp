import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/finanzen.dart';
import 'package:productivity/dataclasses/user.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/dataservice/finanz_rechnung.dart';
import 'package:productivity/dataservice/finanz_service.dart';
import 'package:productivity/dataservice/user_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/provider/user_provider.dart';
import 'package:productivity/widgets/color_picker_dialog.dart';
import 'package:provider/provider.dart';

/// Die Kassen: „Haushalt", „Mein Giro", die Urlaubskasse.
///
/// Dasselbe Muster wie bei den Einkaufslisten — eine Kasse gehört
/// jemandem, wer hinzugefügt wurde, bucht mit. Und derselbe Grund: eine
/// gemeinsame Haushaltskasse und das eigene Taschengeld gehören nicht in
/// dieselbe Spalte.
class KassenPage extends BasePage {
  const KassenPage({super.key}) : super(title: 'Kassen');

  @override
  Widget buildBody(BuildContext context) => const _Kassen();
}

class _Kassen extends StatefulWidget {
  const _Kassen();

  @override
  State<_Kassen> createState() => _KassenState();
}

class _KassenState extends State<_Kassen> {
  List<Kasse> _kassen = [];
  List<User> _leute = [];
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
      // Die Namensliste darf ausfallen: ohne sie kann man keine Mitglieder
      // verwalten, aber die Kassen stehen trotzdem da.
      List<User> leute = [];
      try {
        leute = await UserService.getAllUsers();
      } catch (_) {
        leute = [];
      }
      if (!mounted) return;
      setState(() {
        _kassen = kassen;
        _leute = leute;
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

  String get _ichId =>
      Provider.of<UserProvider>(context, listen: false).user?.id ?? '';

  Future<void> _anlegen() async {
    final eingabe = await showDialog<_Kasseneingabe>(
      context: context,
      builder: (_) => const _KasseDialog(),
    );
    if (eingabe == null) return;
    try {
      await FinanzService.kasseAnlegen(
        eingabe.name,
        art: eingabe.art,
        startCents: eingabe.startCents,
      );
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _bearbeiten(Kasse kasse) async {
    final eingabe = await showDialog<_Kasseneingabe>(
      context: context,
      builder: (_) => _KasseDialog(vorhanden: kasse),
    );
    if (eingabe == null) return;
    try {
      await FinanzService.kasseAendern(
        kasse.id,
        name: eingabe.name,
        art: eingabe.art,
        startCents: eingabe.startCents,
      );
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _farbe(Kasse kasse) async {
    final farbe = await ColorPickerDialog.show(context, kasse.color);
    if (farbe == null) return;
    try {
      await FinanzService.kasseAendern(kasse.id, color: farbe);
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _loeschen(Kasse kasse) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('„${kasse.name}" löschen?'),
        content: const Text(
            'Alle Buchungen darauf gehen mit — auch die der anderen. Das '
            'lässt sich nicht rückgängig machen.'),
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
      await FinanzService.kasseLoeschen(kasse.id);
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _mitglieder(Kasse kasse) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MitgliederSheet(
        kasse: kasse,
        leute: _leute,
        onAendern: () async {
          await _laden();
        },
      ),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(_fehler!, textAlign: TextAlign.center),
        ),
      );
    }

    final ich = _ichId;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _laden,
        child: _kassen.isEmpty
            ? _leer()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                itemCount: _kassen.length,
                itemBuilder: (_, i) {
                  final kasse = _kassen[i];
                  final meins = kasse.gehoert(ich);
                  return _Karte(
                    kasse: kasse,
                    meins: meins,
                    onBearbeiten: meins ? () => _bearbeiten(kasse) : null,
                    onFarbe: meins ? () => _farbe(kasse) : null,
                    onMitglieder: meins ? () => _mitglieder(kasse) : null,
                    onLoeschen: meins ? () => _loeschen(kasse) : null,
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _anlegen,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Kasse'),
      ),
    );
  }

  Widget _leer() => ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.account_balance_wallet_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Noch keine Kasse.\n'
              'Eine reicht für den Anfang — „Haushalt" zum Beispiel.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
          ),
        ],
      );
}

class _Karte extends StatelessWidget {
  final Kasse kasse;
  final bool meins;
  final VoidCallback? onBearbeiten;
  final VoidCallback? onFarbe;
  final VoidCallback? onMitglieder;
  final VoidCallback? onLoeschen;

  const _Karte({
    required this.kasse,
    required this.meins,
    this.onBearbeiten,
    this.onFarbe,
    this.onMitglieder,
    this.onLoeschen,
  });

  static const _arten = {
    'bar': 'Bargeld',
    'giro': 'Girokonto',
    'sparen': 'Sparkonto',
    'kreditkarte': 'Kreditkarte',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final unterzeile = [
      _arten[kasse.art] ?? kasse.art,
      if (!meins) 'von ${kasse.ownerName}',
      if (kasse.memberIds.isNotEmpty)
        '${kasse.memberIds.length} weitere${kasse.memberIds.length == 1 ? '' : ''}',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 44,
              decoration: BoxDecoration(
                color: _farbeVon(kasse.color, context),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(kasse.name,
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(unterzeile,
                      style: text.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant)),
                ],
              ),
            ),
            Text(
              Finanzrechnung.nurBetrag(kasse.saldoCents),
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: kasse.saldoCents < 0 ? colors.error : null,
              ),
            ),
            if (meins)
              PopupMenuButton<String>(
                onSelected: (wahl) {
                  switch (wahl) {
                    case 'bearbeiten':
                      onBearbeiten?.call();
                    case 'farbe':
                      onFarbe?.call();
                    case 'mitglieder':
                      onMitglieder?.call();
                    case 'loeschen':
                      onLoeschen?.call();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'bearbeiten', child: Text('Bearbeiten')),
                  PopupMenuItem(value: 'farbe', child: Text('Farbe')),
                  PopupMenuItem(value: 'mitglieder', child: Text('Wer darf mit?')),
                  PopupMenuItem(value: 'loeschen', child: Text('Löschen')),
                ],
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// Was der Kassen-Dialog zurückgibt.
class _Kasseneingabe {
  final String name;
  final String art;
  final int startCents;

  const _Kasseneingabe(this.name, this.art, this.startCents);
}

class _KasseDialog extends StatefulWidget {
  final Kasse? vorhanden;

  const _KasseDialog({this.vorhanden});

  @override
  State<_KasseDialog> createState() => _KasseDialogState();
}

class _KasseDialogState extends State<_KasseDialog> {
  late final TextEditingController _name;
  late final TextEditingController _start;
  late String _art;

  @override
  void initState() {
    super.initState();
    final v = widget.vorhanden;
    _name = TextEditingController(text: v?.name ?? '');
    _start = TextEditingController(
      text: v == null || v.startCents == 0
          ? ''
          : Finanzrechnung.nurBetrag(v.startCents).replaceAll(' €', ''),
    );
    _art = v?.art ?? 'giro';
  }

  @override
  void dispose() {
    _name.dispose();
    _start.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.vorhanden == null ? 'Neue Kasse' : 'Kasse ändern'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Haushalt, Mein Giro …',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _art,
              decoration: const InputDecoration(labelText: 'Art'),
              items: const [
                DropdownMenuItem(value: 'giro', child: Text('Girokonto')),
                DropdownMenuItem(value: 'bar', child: Text('Bargeld')),
                DropdownMenuItem(value: 'sparen', child: Text('Sparkonto')),
                DropdownMenuItem(
                    value: 'kreditkarte', child: Text('Kreditkarte')),
              ],
              onChanged: (v) => setState(() => _art = v ?? 'giro'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _start,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Anfangsbestand',
                suffixText: '€',
                helperText: 'Was jetzt drauf ist. Später nicht mehr nötig.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              final name = _name.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(
                context,
                _Kasseneingabe(
                    name, _art, Finanzrechnung.cents(_start.text) ?? 0),
              );
            },
            child: const Text('Speichern'),
          ),
        ],
      );
}

/// Wer außer dem Besitzer mitbuchen darf.
class _MitgliederSheet extends StatefulWidget {
  final Kasse kasse;
  final List<User> leute;
  final Future<void> Function() onAendern;

  const _MitgliederSheet({
    required this.kasse,
    required this.leute,
    required this.onAendern,
  });

  @override
  State<_MitgliederSheet> createState() => _MitgliederSheetState();
}

class _MitgliederSheetState extends State<_MitgliederSheet> {
  late Set<String> _drin;
  bool _arbeitet = false;

  @override
  void initState() {
    super.initState();
    _drin = {...widget.kasse.memberIds};
  }

  Future<void> _umschalten(User person, bool rein) async {
    setState(() => _arbeitet = true);
    try {
      if (rein) {
        await FinanzService.mitgliedHinzufuegen(widget.kasse.id, person.id);
      } else {
        await FinanzService.mitgliedEntfernen(widget.kasse.id, person.id);
      }
      setState(() {
        rein ? _drin.add(person.id) : _drin.remove(person.id);
        _arbeitet = false;
      });
      await widget.onAendern();
    } catch (e) {
      if (!mounted) return;
      setState(() => _arbeitet = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ApiFehler.text(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Der Besitzer steht nicht zur Wahl: er ist ohnehin dabei, und ihn
    // abwählbar zu zeigen wäre ein Angebot, das der Server ablehnt.
    final andere =
        widget.leute.where((p) => p.id != widget.kasse.ownerId).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Wer darf auf „${widget.kasse.name}" buchen?',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (andere.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Es gibt sonst niemanden.'),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final person in andere)
                      SwitchListTile(
                        title: Text(
                            '${person.firstname} ${person.lastname}'.trim()),
                        subtitle: Text(person.username),
                        value: _drin.contains(person.id),
                        onChanged: _arbeitet
                            ? null
                            : (rein) => _umschalten(person, rein),
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

Color _farbeVon(String hex, BuildContext context) {
  final sauber = hex.replaceAll('#', '');
  final wert = int.tryParse(sauber, radix: 16);
  if (wert == null || sauber.length != 6) {
    return Theme.of(context).colorScheme.outline;
  }
  return Color(0xFF000000 | wert);
}

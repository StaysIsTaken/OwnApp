import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:productivity/dataclasses/einkauf.dart';
import 'package:productivity/dataclasses/shop.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/dataservice/einkauf_service.dart';
import 'package:productivity/dataservice/shop_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/provider/permission_provider.dart';
import 'package:provider/provider.dart';

/// Die Läden und was dort was kostet.
///
/// Anlegen ging bisher nur nebenbei beim Schreiben einer Einkaufsposition —
/// versteckt in einem Dialog der alten Listenseite. Wer einen Laden
/// umbenennen oder nachsehen wollte, was er über ihn weiß, hatte keinen Ort
/// dafür.
///
/// Die Preise stehen aufgeklappt unter dem Laden und nicht auf einer eigenen
/// Seite: „welche Läden habe ich" und „was kostet dort was" sind dieselbe
/// Frage, nur zwei Ebenen tief.
class LaedenPage extends BasePage {
  const LaedenPage({super.key}) : super(title: 'Läden');

  @override
  Widget buildBody(BuildContext context) => const _Laeden();
}

class _Laeden extends StatefulWidget {
  const _Laeden();

  @override
  State<_Laeden> createState() => _LaedenState();
}

class _LaedenState extends State<_Laeden> {
  List<Shop> _laeden = [];
  bool _laedt = true;
  String? _fehler;

  /// Preise je Laden, erst beim Aufklappen geholt. Alle auf einmal zu laden
  /// hiesse, für zwanzig Läden zwanzig Abfragen zu stellen, von denen man
  /// eine ansieht.
  final Map<String, List<Warenpreis>> _preise = {};
  final Set<String> _laedtPreise = {};

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
      final liste = await ShopService.loadAll();
      liste.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _laeden = liste;
        _laedt = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _laedt = false;
        _fehler = ApiFehler.text(e);
      });
    }
  }

  Future<void> _preiseHolen(Shop laden) async {
    if (_preise.containsKey(laden.id) || _laedtPreise.contains(laden.id)) {
      return;
    }
    setState(() => _laedtPreise.add(laden.id));
    final liste = await EinkaufService.preiseImLaden(laden.id);
    if (!mounted) return;
    setState(() {
      _preise[laden.id] = liste;
      _laedtPreise.remove(laden.id);
    });
  }

  Future<void> _anlegenOderUmbenennen([Shop? laden]) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(
        titel: laden == null ? 'Neuer Laden' : 'Laden umbenennen',
        vorgabe: laden?.name,
      ),
    );
    if (name == null || name.trim().isEmpty) return;

    try {
      if (laden == null) {
        await ShopService.create(
            Shop(id: '', name: name.trim(), createdAt: DateTime.now()));
      } else {
        await ShopService.update(laden.id, name.trim());
        // Der Name steckt in den Preiszeilen mit drin.
        _preise.remove(laden.id);
      }
      await _laden();
    } on DioException catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _loeschen(Shop laden) async {
    final anzahl = _preise[laden.id]?.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('„${laden.name}" löschen?'),
        content: Text(
          anzahl == null || anzahl == 0
              ? 'Der Laden verschwindet aus der Auswahl.'
              : 'Der Laden verschwindet — und mit ihm $anzahl gemerkte '
                  'Preise. Die Einkaufslisten selbst bleiben.',
        ),
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
      await ShopService.delete(laden.id);
      _preise.remove(laden.id);
      await _laden();
    } on DioException catch (e) {
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
    final texte = Theme.of(context).textTheme;
    final darfSchreiben = context.watch<PermissionProvider>().darf('shops:write');

    if (_laedt) return const Center(child: CircularProgressIndicator());

    if (_fehler != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_fehler!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _laden, child: const Text('Nochmal')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      floatingActionButton: darfSchreiben
          ? FloatingActionButton.extended(
              onPressed: () => _anlegenOderUmbenennen(),
              icon: const Icon(Icons.add),
              label: const Text('Laden'),
            )
          : null,
      body: _laeden.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront_outlined,
                      size: 64, color: colors.outline.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('Noch keine Läden',
                      style: texte.bodyLarge?.copyWith(color: colors.outline)),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      'Läden brauchst du, um Preise zu merken — „bei Aldi '
                      'zuletzt 0,89" steht sonst nirgends.',
                      textAlign: TextAlign.center,
                      style: texte.labelMedium?.copyWith(color: colors.outline),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: _laeden.length,
              itemBuilder: (_, i) => _LadenKarte(
                laden: _laeden[i],
                preise: _preise[_laeden[i].id],
                laedt: _laedtPreise.contains(_laeden[i].id),
                darfSchreiben: darfSchreiben,
                beimAufklappen: () => _preiseHolen(_laeden[i]),
                beimUmbenennen: () => _anlegenOderUmbenennen(_laeden[i]),
                beimLoeschen: () => _loeschen(_laeden[i]),
              ),
            ),
    );
  }
}

class _LadenKarte extends StatelessWidget {
  final Shop laden;
  final List<Warenpreis>? preise;
  final bool laedt;
  final bool darfSchreiben;
  final VoidCallback beimAufklappen;
  final VoidCallback beimUmbenennen;
  final VoidCallback beimLoeschen;

  const _LadenKarte({
    required this.laden,
    required this.preise,
    required this.laedt,
    required this.darfSchreiben,
    required this.beimAufklappen,
    required this.beimUmbenennen,
    required this.beimLoeschen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        onExpansionChanged: (auf) {
          if (auf) beimAufklappen();
        },
        shape: const Border(),
        leading: CircleAvatar(
          backgroundColor: colors.secondaryContainer,
          child: Icon(Icons.storefront_outlined,
              size: 20, color: colors.onSecondaryContainer),
        ),
        title: Text(laden.name,
            style: texte.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: preise == null
            ? null
            : Text(preise!.isEmpty
                ? 'Noch keine Preise gemerkt'
                : '${preise!.length} ${preise!.length == 1 ? "Preis" : "Preise"}'),
        trailing: darfSchreiben
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Umbenennen',
                    onPressed: beimUmbenennen,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 20, color: colors.error),
                    tooltip: 'Löschen',
                    onPressed: beimLoeschen,
                  ),
                ],
              )
            : null,
        children: [
          if (laedt)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (preise == null || preise!.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Hier ist noch nichts notiert. Preise merkt man sich auf der '
                'Seite „Preise" oder beim Schreiben einer Einkaufsposition.',
                style: texte.labelMedium?.copyWith(color: colors.outline),
              ),
            )
          else
            for (final p in preise!)
              ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.only(left: 72, right: 16, bottom: 4),
                title: Text(p.bezeichnung),
                subtitle: p.notiertAm == null
                    ? null
                    : Text('notiert am ${p.notiertAm!.day}.'
                        '${p.notiertAm!.month}.${p.notiertAm!.year}'),
                trailing: Text(
                  p.alsText(),
                  style: texte.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold, color: colors.primary),
                ),
              ),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titel),
      content: TextField(
        controller: _feld,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'z. B. Aldi, Rewe, Wochenmarkt',
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
}

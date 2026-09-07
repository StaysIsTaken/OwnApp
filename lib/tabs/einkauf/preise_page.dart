import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/einkauf.dart';
import 'package:productivity/dataclasses/shop.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/dataservice/einkauf_service.dart';
import 'package:productivity/dataservice/shop_service.dart';
import 'package:productivity/main.dart';

/// Was wo wie teuer war — zum Nachschlagen und Eintragen.
///
/// Beim Schreiben einer Position erscheint der Preis ohnehin dort, wo man
/// tippt; das ist der wichtigere Ort. Diese Seite ist für den anderen
/// Moment: nachsehen, vergleichen, einen Preis nachtragen, den man im
/// Laden gesehen hat.
///
/// Das Wissen hängt an der Bezeichnung, nicht an einem Listeneintrag —
/// deshalb überlebt es den Einkauf und steht hier auch dann, wenn die
/// Liste längst weggeräumt ist.
class PreisePage extends BasePage {
  const PreisePage({super.key}) : super(title: 'Preise');

  @override
  Widget buildBody(BuildContext context) => const _Preise();
}

class _Preise extends StatefulWidget {
  const _Preise();

  @override
  State<_Preise> createState() => _PreiseState();
}

class _PreiseState extends State<_Preise> {
  final _suche = TextEditingController();
  List<Warenpreis> _treffer = [];
  List<Shop> _laeden = [];
  bool _sucht = false;
  bool _gesucht = false;

  @override
  void initState() {
    super.initState();
    _laedenLaden();
  }

  @override
  void dispose() {
    _suche.dispose();
    super.dispose();
  }

  Future<void> _laedenLaden() async {
    try {
      final laeden = await ShopService.loadAll();
      if (mounted) setState(() => _laeden = laeden);
    } catch (_) {
      // Ohne Laden lässt sich nichts eintragen – das sagt der Dialog dann.
    }
  }

  Future<void> _suchen() async {
    final name = _suche.text.trim();
    if (name.isEmpty) return;
    setState(() => _sucht = true);
    final preise = await EinkaufService.preise(name);
    if (!mounted) return;
    setState(() {
      _treffer = preise;
      _sucht = false;
      _gesucht = true;
    });
  }

  Future<void> _eintragen() async {
    if (_laeden.isEmpty) {
      _melde('Erst einen Laden anlegen — unter Verwaltung → Läden.');
      return;
    }
    final ergebnis = await showDialog<bool>(
      context: context,
      builder: (_) => _PreisDialog(
        laeden: _laeden,
        vorgabe: _suche.text.trim(),
      ),
    );
    if (ergebnis == true && _suche.text.trim().isNotEmpty) await _suchen();
  }

  void _melde(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _suche,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Wonach suchst du? z. B. Milch',
                prefixIcon: const Icon(Icons.search_rounded),
                border: const OutlineInputBorder(),
                suffixIcon: _suche.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() {
                          _suche.clear();
                          _treffer = [];
                          _gesucht = false;
                        }),
                      ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _suchen(),
            ),
          ),
          Expanded(child: _inhalt(colors)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _eintragen,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Preis'),
      ),
    );
  }

  Widget _inhalt(ColorScheme colors) {
    if (_sucht) return const Center(child: CircularProgressIndicator());

    if (!_gesucht) {
      return _hinweis(
        colors,
        Icons.savings_outlined,
        'Was hat was wo gekostet?\n'
        'Oben eine Ware eingeben — der Name genügt.',
      );
    }

    if (_treffer.isEmpty) {
      return _hinweis(
        colors,
        Icons.search_off_rounded,
        'Zu „${_suche.text.trim()}" ist noch nichts bekannt.\n'
        'Unten rechts einen Preis eintragen.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
      itemCount: _treffer.length,
      itemBuilder: (_, i) {
        final p = _treffer[i];
        // Der erste ist der günstigste – das sortiert der Server.
        final guenstigster = i == 0 && _treffer.length > 1;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: guenstigster
                  ? colors.primaryContainer
                  : colors.surfaceContainerHighest,
              child: Icon(
                guenstigster ? Icons.trending_down_rounded : Icons.store_outlined,
                color: guenstigster ? colors.onPrimaryContainer : null,
              ),
            ),
            title: Text(p.shopName,
                style: TextStyle(
                    fontWeight:
                        guenstigster ? FontWeight.bold : FontWeight.normal)),
            subtitle: p.notiertAm == null
                ? null
                : Text('notiert am '
                    '${p.notiertAm!.day}.${p.notiertAm!.month}.${p.notiertAm!.year}'),
            trailing: Text(
              p.alsText(),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: guenstigster ? colors.primary : colors.onSurface,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _hinweis(ColorScheme colors, IconData icon, String text) => ListView(
        children: [
          const SizedBox(height: 60),
          Icon(icon, size: 56, color: colors.outline),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.4)),
          ),
        ],
      );
}

class _PreisDialog extends StatefulWidget {
  final List<Shop> laeden;
  final String vorgabe;

  const _PreisDialog({required this.laeden, required this.vorgabe});

  @override
  State<_PreisDialog> createState() => _PreisDialogState();
}

class _PreisDialogState extends State<_PreisDialog> {
  late final _ware = TextEditingController(text: widget.vorgabe);
  final _preis = TextEditingController();
  final _menge = TextEditingController();
  late String _shopId = widget.laeden.first.id;
  bool _speichert = false;
  String? _fehler;

  @override
  void dispose() {
    _ware.dispose();
    _preis.dispose();
    _menge.dispose();
    super.dispose();
  }

  double? get _preiswert {
    // Komma wie auf dem Preisschild – Dart will einen Punkt.
    final roh = _preis.text.trim().replaceAll(',', '.');
    final wert = double.tryParse(roh);
    return (wert == null || wert <= 0) ? null : wert;
  }

  Future<void> _speichern() async {
    final ware = _ware.text.trim();
    final preis = _preiswert;
    if (ware.isEmpty || preis == null) return;
    setState(() => _speichert = true);
    try {
      await EinkaufService.preisMerken(
        bezeichnung: ware,
        shopId: _shopId,
        preis: preis,
        menge: double.tryParse(_menge.text.trim().replaceAll(',', '.')),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _speichert = false;
        _fehler = ApiFehler.text(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Preis merken'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _ware,
                autofocus: widget.vorgabe.isEmpty,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Ware',
                  hintText: 'z. B. Milch',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _shopId,
                decoration: const InputDecoration(
                    labelText: 'Laden', border: OutlineInputBorder()),
                items: [
                  for (final l in widget.laeden)
                    DropdownMenuItem(value: l.id, child: Text(l.name)),
                ],
                onChanged: (v) => setState(() => _shopId = v ?? _shopId),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _preis,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Preis',
                        suffixText: '€',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _menge,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'für Menge',
                        hintText: 'optional',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '„2,49 für 500" sagt mehr als „2,49". Die Menge ist '
                'freiwillig.',
                style: TextStyle(
                    fontSize: 12, color: colors.onSurfaceVariant, height: 1.3),
              ),
              if (_fehler != null) ...[
                const SizedBox(height: 12),
                Text(_fehler!, style: TextStyle(color: colors.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _speichert ? null : () => Navigator.pop(context, false),
            child: const Text('Abbrechen')),
        FilledButton(
          onPressed: (_speichert ||
                  _ware.text.trim().isEmpty ||
                  _preiswert == null)
              ? null
              : _speichern,
          child: const Text('Merken'),
        ),
      ],
    );
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/dashboard_page.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/dataservice/dashboard_page_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/provider/permission_provider.dart';
import 'package:productivity/provider/tablet_provider.dart';
import 'package:productivity/tabs/tablet/tablet_seite.dart';
import 'package:provider/provider.dart';

/// Die Küchenansicht: mehrere Seiten, jede mit eigenen Kacheln.
///
/// Bewusst ohne Menü und ohne die übrige App: ein Gerät, das in der Küche
/// steht, soll eine Sache zeigen und sonst nichts. Zurück kommt man über
/// den Schalter oben rechts.
class TabletDashboard extends StatefulWidget {
  const TabletDashboard({super.key});

  @override
  State<TabletDashboard> createState() => _TabletDashboardState();
}

class _TabletDashboardState extends State<TabletDashboard> {
  List<DashboardSeite> _seiten = [];
  int _aktuell = 0;
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
      final seiten =
          await DashboardPageService.laden(mode: DashboardSeite.modeTablet);
      if (!mounted) return;
      setState(() {
        _seiten = seiten;
        _aktuell = _aktuell.clamp(0, seiten.isEmpty ? 0 : seiten.length - 1);
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

  Future<void> _seiteAnlegen() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NameDialog(titel: 'Neue Seite'),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await DashboardPageService.anlegen(
          name: name.trim(), mode: DashboardSeite.modeTablet);
      await _laden();
      if (mounted) setState(() => _aktuell = _seiten.length - 1);
    } on DioException catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _seiteUmbenennen(DashboardSeite seite) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(titel: 'Seite umbenennen', vorgabe: seite.name),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await DashboardPageService.umbenennen(seite.id, name.trim());
      await _laden();
    } on DioException catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _seiteLoeschen(DashboardSeite seite) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('„${seite.name}" löschen?'),
        content: const Text(
          'Die Seite und ihre Kachelanordnung verschwinden. Deine Daten '
          'bleiben – es geht nur die Darstellung.',
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
      await DashboardPageService.loeschen(seite.id);
      if (mounted) setState(() => _aktuell = 0);
      await _laden();
    } on DioException catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  void _melde(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _verlassen() async {
    await context.read<TabletProvider>().setzen(false);
    if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // Wer das Recht verliert, während das Gerät läuft, soll nicht in einer
    // Ansicht festsitzen, die ihm nichts mehr zeigt.
    if (!context.watch<PermissionProvider>().darfTablet) {
      return _Hinweis(
        text: 'Für die Küchenansicht fehlt dir die Berechtigung.',
        knopf: 'Zurück zur App',
        onDruck: _verlassen,
      );
    }

    if (_laedt) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_fehler != null) {
      return _Hinweis(text: _fehler!, knopf: 'Nochmal', onDruck: _laden);
    }
    if (_seiten.isEmpty) {
      return _Hinweis(
        icon: Icons.tablet_mac_rounded,
        text: 'Noch keine Seite für die Küchenansicht.\n'
            'Leg eine an und stell zusammen, was darauf stehen soll.',
        knopf: 'Erste Seite anlegen',
        onDruck: _seiteAnlegen,
        zweiterKnopf: 'Küchenmodus verlassen',
        onZweiter: _verlassen,
      );
    }

    final seite = _seiten[_aktuell];

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _Kopfzeile(
              seiten: _seiten,
              aktuell: _aktuell,
              onWechsel: (i) => setState(() => _aktuell = i),
              onNeu: _seiteAnlegen,
              onUmbenennen: () => _seiteUmbenennen(seite),
              onLoeschen: () => _seiteLoeschen(seite),
              onVerlassen: _verlassen,
            ),
            Expanded(
              // Key je Seite: sonst behielte die neue Seite den Zustand der
              // alten und zeigte kurz deren Kacheln.
              child: TabletSeitenInhalt(key: ValueKey(seite.key), seite: seite),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seitenwechsel und Verwaltung – bewusst große Flächen.
class _Kopfzeile extends StatelessWidget {
  final List<DashboardSeite> seiten;
  final int aktuell;
  final ValueChanged<int> onWechsel;
  final VoidCallback onNeu;
  final VoidCallback onUmbenennen;
  final VoidCallback onLoeschen;
  final VoidCallback onVerlassen;

  const _Kopfzeile({
    required this.seiten,
    required this.aktuell,
    required this.onWechsel,
    required this.onNeu,
    required this.onUmbenennen,
    required this.onLoeschen,
    required this.onVerlassen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < seiten.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _SeitenKnopf(
                        name: seiten[i].name,
                        aktiv: i == aktuell,
                        onDruck: () => onWechsel(i),
                      ),
                    ),
                  IconButton(
                    onPressed: onNeu,
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'Seite hinzufügen',
                    iconSize: 26,
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            iconSize: 28,
            onSelected: (wahl) => switch (wahl) {
              'umbenennen' => onUmbenennen(),
              'loeschen' => onLoeschen(),
              _ => onVerlassen(),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'umbenennen', child: Text('Seite umbenennen')),
              PopupMenuItem(value: 'loeschen', child: Text('Seite löschen')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'verlassen', child: Text('Küchenmodus verlassen')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeitenKnopf extends StatelessWidget {
  final String name;
  final bool aktiv;
  final VoidCallback onDruck;

  const _SeitenKnopf({
    required this.name,
    required this.aktiv,
    required this.onDruck,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: aktiv ? colors.primary : colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onDruck,
        child: Padding(
          // Grosszuegig: das bedient jemand im Vorbeigehen, oft mit nassen
          // oder mehligen Fingern.
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Text(
            name,
            style: TextStyle(
              fontSize: 17,
              fontWeight: aktiv ? FontWeight.w600 : FontWeight.normal,
              color: aktiv ? colors.onPrimary : colors.onSurface,
            ),
          ),
        ),
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
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'z. B. Wochenplan',
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

class _Hinweis extends StatelessWidget {
  final String text;
  final String knopf;
  final VoidCallback onDruck;
  final IconData icon;
  final String? zweiterKnopf;
  final VoidCallback? onZweiter;

  const _Hinweis({
    required this.text,
    required this.knopf,
    required this.onDruck,
    this.icon = Icons.info_outline,
    this.zweiterKnopf,
    this.onZweiter,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: colors.outline),
              const SizedBox(height: 20),
              Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, height: 1.4)),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: onDruck,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 18)),
                child: Text(knopf, style: const TextStyle(fontSize: 16)),
              ),
              if (zweiterKnopf != null) ...[
                const SizedBox(height: 8),
                TextButton(onPressed: onZweiter, child: Text(zweiterKnopf!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

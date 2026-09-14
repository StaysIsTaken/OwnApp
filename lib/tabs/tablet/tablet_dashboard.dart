import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/dashboard_page.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/dataservice/dashboard_page_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/provider/permission_provider.dart';
import 'package:productivity/provider/planner_provider.dart';
import 'package:productivity/provider/settings_provider.dart';
import 'package:productivity/provider/sprach_provider.dart';
import 'package:productivity/provider/tablet_provider.dart';
import 'package:productivity/provider/tablet_seiten_provider.dart';
import 'package:productivity/provider/timer_provider.dart';
import 'package:productivity/tabs/tablet/tablet_seite.dart';
import 'package:productivity/widgets/sprach_leiste.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Die Küchenansicht: mehrere Seiten, jede mit eigenen Kacheln.
///
/// Bewusst ohne Menü und ohne die übrige App: ein Gerät, das in der Küche
/// steht, soll eine Sache zeigen und sonst nichts. Zurück kommt man über
/// den Schalter oben rechts.
///
/// Diese Klasse hält nur noch die beiden Provider, die es ausschließlich hier
/// gibt: die Seiten und die Sprachbedienung. Beide sind bewusst nicht app-weit
/// — auf dem Telefon gibt es weder Küchenseiten noch einen Grund zuzuhören.
class TabletDashboard extends StatefulWidget {
  const TabletDashboard({super.key});

  @override
  State<TabletDashboard> createState() => _TabletDashboardState();
}

class _TabletDashboardState extends State<TabletDashboard> {
  late final TabletSeitenProvider _seiten;
  late final SprachProvider _sprache;

  @override
  void initState() {
    super.initState();
    _seiten = TabletSeitenProvider();
    // Der Planer steht app-weit ueber dieser Ansicht; die Sprachbedienung
    // stellt darueber „zeige nur … Kalender an" ein.
    final planer = context.read<PlannerProvider>();
    // Der Timer steht ebenfalls app-weit: er soll weiterlaufen, wenn man
    // die Kuechenansicht verlaesst, und per Zuruf stellbar sein.
    _sprache = SprachProvider(_seiten, planer, context.read<TimerProvider>());
    _seiten.laden();
    unawaited(planer.loadKalender(alle: true));
    // Ein Küchendisplay, das nach zwei Minuten schwarz wird, ist keins.
    unawaited(_bildschirmWachHalten(true));
  }

  @override
  void dispose() {
    unawaited(_bildschirmWachHalten(false));
    _sprache.dispose();
    _seiten.dispose();
    super.dispose();
  }

  /// Auf Plattformen ohne Unterstützung ist ein Fehlschlag kein Fehler — die
  /// Ansicht funktioniert auch dann, der Bildschirm geht eben irgendwann aus.
  Future<void> _bildschirmWachHalten(bool an) async {
    try {
      if (an) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {
      // absichtlich still
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _seiten),
        ChangeNotifierProvider.value(value: _sprache),
      ],
      child: const _Kuechenansicht(),
    );
  }
}

class _Kuechenansicht extends StatefulWidget {
  const _Kuechenansicht();

  @override
  State<_Kuechenansicht> createState() => _KuechenansichtState();
}

class _KuechenansichtState extends State<_Kuechenansicht> {
  /// Womit das Weckwort zuletzt eingeschaltet wurde: Schalter und Schwelle,
  /// zu einer Zeichenkette verschmolzen. Damit merkt
  /// [didChangeDependencies], ob sich an der Einstellung wirklich etwas
  /// geändert hat — sonst würde das Modell bei jedem Neuaufbau neu geladen.
  String? _wakewordStand;

  /// Einrichten an oder aus. Gehört hierher und nicht auf die Seite: der
  /// Schalter sitzt in der Kopfzeile, und der Modus bleibt beim
  /// Seitenwechsel erhalten — wer mehrere Seiten einrichtet, will nicht
  /// jedes Mal neu einschalten.
  bool _bearbeiten = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Provider.of statt context.watch: watch ist laut Provider ausdrücklich
    // auf build beschränkt, Provider.of hat die Einschränkung nicht und
    // weckt didChangeDependencies bei jeder Änderung.
    final settings = Provider.of<SettingsProvider>(context);
    // Ohne die Rechte fürs Erkennen und Ausführen wäre das Lauschen
    // vergeudet: der Zuruf lief in ein 403. Dann bleibt die Küchenansicht
    // eine reine Anzeige.
    final darfSprache = Provider.of<PermissionProvider>(context).darfSprache;
    // Fürs Wetter: der Sprach-Ablauf soll die Einstellungen nicht selbst
    // kennen müssen, also reicht das Dashboard die Stadt durch. Steht vor dem
    // Abgleich unten — der kehrt frueh zurueck, wenn sich am Weckwort nichts
    // geaendert hat, und die Stadt bliebe dann stehen.
    context.read<SprachProvider>().wetterStadt = settings.weatherCity;

    final soll = settings.wakewordAn && darfSprache
        ? 'an:${settings.wakewordSchwelle.toStringAsFixed(2)}'
        : '';
    if (soll == _wakewordStand) return;
    final vorher = _wakewordStand;
    _wakewordStand = soll;

    final sprache = context.read<SprachProvider>();
    if (soll.isEmpty) {
      unawaited(sprache.wakewordAusschalten());
    } else {
      // Bei geänderter Schwelle erst ausschalten: sie steckt in der
      // Konfiguration des Erkenners, und die liest er nur beim Erzeugen.
      unawaited(() async {
        if (vorher != null && vorher.isNotEmpty) {
          await sprache.wakewordAusschalten();
        }
        await sprache.wakewordEinschalten(schwelle: settings.wakewordSchwelle);
        // Beides gehört zum selben Zustand: ein Gerät, das für den Raum
        // zuhört. Erlaubt der Server keine Stimmerkennung, läuft alles
        // weiter -- dann fragt Jarvis eben nach, wer spricht.
        await sprache.stimmerkennungStarten();
      }());
    }
  }

  Future<void> _seiteAnlegen() async {
    // Den Provider VOR dem ersten await greifen: danach ist nicht sicher, ob
    // dieses Widget noch im Baum hängt, und context.read würde werfen.
    final seiten = context.read<TabletSeitenProvider>();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NameDialog(titel: 'Neue Seite'),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await DashboardPageService.anlegen(
          name: name.trim(), mode: DashboardSeite.modeTablet);
      await seiten.laden();
      seiten.zurLetzten();
    } on DioException catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _seiteUmbenennen(DashboardSeite seite) async {
    final seiten = context.read<TabletSeitenProvider>();
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          _NameDialog(titel: 'Seite umbenennen', vorgabe: seite.name),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await DashboardPageService.umbenennen(seite.id, name.trim());
      await seiten.laden();
    } on DioException catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _seiteLoeschen(DashboardSeite seite) async {
    final seiten = context.read<TabletSeitenProvider>();
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
      seiten.zurErsten();
      await seiten.laden();
    } on DioException catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  void _melde(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _verlassen() async {
    await context.read<TabletProvider>().setzen(false);
    if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final seiten = context.watch<TabletSeitenProvider>();

    // Wer das Recht verliert, während das Gerät läuft, soll nicht in einer
    // Ansicht festsitzen, die ihm nichts mehr zeigt.
    if (!context.watch<PermissionProvider>().darfTablet) {
      return _Hinweis(
        text: 'Für die Küchenansicht fehlt dir die Berechtigung.',
        knopf: 'Zurück zur App',
        onDruck: _verlassen,
      );
    }

    if (seiten.laedt) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (seiten.fehler != null) {
      return _Hinweis(text: seiten.fehler!, knopf: 'Nochmal', onDruck: seiten.laden);
    }
    if (seiten.seiten.isEmpty) {
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

    final seite = seiten.seite!;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _Kopfzeile(
                  seiten: seiten.seiten,
                  aktuell: seiten.aktuell,
                  onWechsel: seiten.wechsleZu,
                  onNeu: _seiteAnlegen,
                  onUmbenennen: () => _seiteUmbenennen(seite),
                  onLoeschen: () => _seiteLoeschen(seite),
                  onVerlassen: _verlassen,
                  bearbeiten: _bearbeiten,
                  onBearbeiten: () => setState(() => _bearbeiten = !_bearbeiten),
                ),
                Expanded(
                  // Key je Seite: sonst behielte die neue Seite den Zustand der
                  // alten und zeigte kurz deren Kacheln. Der Stand kommt dazu,
                  // damit ein per Sprache eingetragener Termin sofort auf der
                  // Kachel daneben steht.
                  child: TabletSeitenInhalt(
                    key: ValueKey('${seite.key}-${seiten.stand}'),
                    seite: seite,
                    bearbeiten: _bearbeiten,
                  ),
                ),
              ],
            ),
            const SprachLeiste(),
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
  final bool bearbeiten;
  final VoidCallback onBearbeiten;

  const _Kopfzeile({
    required this.seiten,
    required this.aktuell,
    required this.onWechsel,
    required this.onNeu,
    required this.onUmbenennen,
    required this.onLoeschen,
    required this.onVerlassen,
    required this.bearbeiten,
    required this.onBearbeiten,
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
          // Beim Einrichten bleibt der Zustand sichtbar: ein Haken in der
          // Leiste sagt, dass gerade gezogen und geaendert werden kann.
          if (bearbeiten)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton.icon(
                onPressed: onBearbeiten,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Fertig', style: TextStyle(fontSize: 16)),
              ),
            ),
          PopupMenuButton<String>(
            iconSize: 28,
            onSelected: (wahl) => switch (wahl) {
              'einrichten' => onBearbeiten(),
              'umbenennen' => onUmbenennen(),
              'loeschen' => onLoeschen(),
              _ => onVerlassen(),
            },
            itemBuilder: (_) => [
              // Der Stift sass frueher als schwebender Knopf unten rechts.
              // Auf einem Geraet, das nur zeigen soll, ist ein Knopf im Bild
              // eine Einladung, ihn versehentlich zu treffen – hier stoert
              // er niemanden und ist trotzdem zu finden.
              PopupMenuItem(
                value: 'einrichten',
                child: Text(bearbeiten
                    ? 'Einrichten beenden'
                    : 'Seite einrichten'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: 'umbenennen', child: Text('Seite umbenennen')),
              const PopupMenuItem(
                  value: 'loeschen', child: Text('Seite löschen')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: 'verlassen', child: Text('Küchenmodus verlassen')),
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

import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/dashboard_page.dart';
import 'package:productivity/dataclasses/ingredient.dart';
import 'package:productivity/dataclasses/journal_entry.dart';
import 'package:productivity/dataclasses/note.dart';
import 'package:productivity/dataclasses/pantry_item.dart';
import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/dataclasses/pantry_extras.dart';
import 'package:productivity/dataclasses/task.dart';
import 'package:productivity/dataclasses/time_entry.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/dataservice/ingredient_service.dart';
import 'package:productivity/dataservice/journal_service.dart';
import 'package:productivity/dataservice/note_service.dart';
import 'package:productivity/dataservice/pantry_service.dart';
import 'package:productivity/dataservice/planner_service.dart';
import 'package:productivity/dataservice/rechte_zuordnung.dart';
import 'package:productivity/dataservice/shopping_list_service.dart';
import 'package:productivity/dataclasses/kalender.dart';
import 'package:productivity/dataservice/calendar_service.dart';
import 'package:productivity/dataservice/feed_service.dart';
import 'package:productivity/dataservice/task_service.dart';
import 'package:productivity/dataservice/time_entry_service.dart';
import 'package:productivity/provider/permission_provider.dart';
import 'package:productivity/tabs/dashboard/custom/custom_tile_card.dart';
import 'package:productivity/tabs/dashboard/custom/tile_catalog.dart';
import 'package:productivity/tabs/dashboard/custom/tile_data.dart';
import 'package:productivity/tabs/dashboard/custom/tile_editor.dart';
import 'package:productivity/tabs/dashboard/custom/tile_spec.dart';
import 'package:productivity/tabs/dashboard/dashboard_prefs.dart';
import 'package:productivity/tabs/dashboard/kalender_auswahl.dart';
import 'package:productivity/tabs/dashboard/seiten_einstellungen.dart';
import 'package:productivity/tabs/tablet/kalender_leiste.dart';
import 'package:productivity/widgets/dashboard/reorderable_tile.dart';
import 'package:provider/provider.dart';

/// Der Inhalt einer Küchen-Seite: Kacheln, die der Nutzer selbst
/// zusammenstellt.
///
/// Nutzt denselben Baukasten wie das übrige Dashboard — Quelle,
/// Darstellung, Filter. Anders ist nur die Größe: zwei Spalten statt drei,
/// mehr Luft, größere Knöpfe. Ein Gerät, das an der Wand hängt, wird aus
/// zwei Metern gelesen und im Vorbeigehen bedient.
class TabletSeitenInhalt extends StatefulWidget {
  final DashboardSeite seite;

  const TabletSeitenInhalt({super.key, required this.seite});

  @override
  State<TabletSeitenInhalt> createState() => _TabletSeitenInhaltState();
}

class _TabletSeitenInhaltState extends State<TabletSeitenInhalt> {
  List<CustomTile> _kacheln = [];
  List<String> _reihenfolge = [];
  Set<String> _versteckt = {};
  SeitenEinstellungen _einstellungen = SeitenEinstellungen.leer;

  bool _laedt = true;
  bool _bearbeiten = false;
  String? _fehler;

  DashboardData _daten = const DashboardData();

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    setState(() => _laedt = true);
    final stand = await DashboardPrefs.load(widget.seite.key);
    if (!mounted) return;
    setState(() {
      _kacheln = stand.tiles;
      _reihenfolge = stand.order;
      _versteckt = stand.hidden;
      _einstellungen = stand.einstellungen;
    });
    await _datenLaden();
  }

  /// Jede Quelle für sich – wie auf der Übersichtsseite. Ein fehlendes
  /// Recht lässt eine Kachel weg, statt die Seite abzureißen.
  Future<void> _datenLaden() async {
    final rechte = context.read<PermissionProvider>();
    var versucht = 0;
    var gescheitert = 0;

    Future<List<T>> hole<T>(String quelle, Future<List<T>> Function() laden) async {
      final noetig = rechtJeQuelle[quelle];
      if (noetig != null && !rechte.darf(noetig)) return <T>[];
      versucht++;
      try {
        return await laden();
      } catch (e) {
        if (!ApiFehler.istVerboten(e)) gescheitert++;
        return <T>[];
      }
    }

    final ergebnisse = await Future.wait([
      hole('tasks', TaskService.loadAll),
      hole('time', TimeEntryService.loadAll),
      // Nur die Kalender, die diese Seite zeigen soll – hier entscheidet
      // sich, ob die Muellabfuhr auftaucht oder nicht.
      hole(
          'planner',
          () => PlannerService.loadAll(
                kalender: _einstellungen.kalender,
                alle: _einstellungen.alleKalender,
              )),
      hole('shopping', ShoppingListService.loadAll),
      hole('pantry', PantryService.loadAll),
      hole('ingredients', IngredientService.loadAll),
      hole('notes', NoteService.loadAll),
      hole('journal', JournalService.loadAll),
    ]);

    // Farben der Kalender – damit die Wochenansicht ihre Termine danach
    // faerben kann statt alle gleich.
    final kalender = await _stillHolen(
        () => CalendarService.laden(alle: _einstellungen.alleKalender));

    // Nachrichten und Witz gehen ins Netz und werden deshalb nur geholt,
    // wenn auch eine Kachel danach fragt.
    final gebraucht = TileCatalog.extras(_kacheln);
    final nachrichten = gebraucht.contains(TileExtras.nachrichten)
        ? await _stillHolen(() => FeedService.nachrichten(anzahl: 10))
        : const <Meldung>[];
    final witz = gebraucht.contains(TileExtras.witz)
        ? await _stillHolen(() => FeedService.witz())
        : null;

    if (!mounted) return;
    final zutaten = ergebnisse[5] as List<Ingredient>;
    setState(() {
      _daten = DashboardData(
        nachrichten: nachrichten ?? const [],
        witz: witz,
        kalenderFarben: {
          for (final k in kalender ?? const <Kalender>[]) k.id: k.color,
        },
        tasks: ergebnisse[0] as List<Task>,
        timeEntries: ergebnisse[1] as List<TimeEntry>,
        plannerEntries: ergebnisse[2] as List<PlannerEntry>,
        shoppingItems: ergebnisse[3] as List<ShoppingListItem>,
        pantryItems: ergebnisse[4] as List<PantryItem>,
        notes: ergebnisse[6] as List<Note>,
        journalEntries: ergebnisse[7] as List<JournalEntry>,
        ingredientMap: {for (final z in zutaten) z.id: z},
      );
      _fehler = (versucht > 0 && gescheitert == versucht)
          ? 'Der Server ist gerade nicht erreichbar.'
          : null;
      _laedt = false;
    });
  }

  /// Holt etwas, das ausfallen darf. Ein Feed, der nicht antwortet, lässt
  /// eine Kachel leer — er reißt die Seite nicht ab.
  Future<T?> _stillHolen<T>(Future<T> Function() laden) async {
    try {
      return await laden();
    } catch (_) {
      return null;
    }
  }

  Future<void> _speichern() async {
    await DashboardPrefs.save(
      widget.seite.key, _reihenfolge, _versteckt,
      tiles: _kacheln, einstellungen: _einstellungen,
    );
  }

  Future<void> _kalenderWaehlen() async {
    final wunsch = await zeigeKalenderAuswahl(
      context,
      aktuell: _einstellungen,
      hatTerminkachel: TileCatalog.zeigtTermine(_kacheln),
    );
    if (wunsch == null || !mounted) return;
    setState(() => _einstellungen = wunsch.einstellungen);
    await _speichern();
    if (wunsch.kachelAnlegen && mounted) {
      // Der Filter allein zeigt nichts – wer ihn auf einer leeren Seite
      // setzt, wollte eine Kalenderkachel.
      await _kachelHinzufuegen();
      return;
    }
    await _datenLaden();
  }

  Future<void> _kachelHinzufuegen() async {
    final neu = await showTileEditor(context,
        zone: CustomTile.zoneKopf, daten: _daten);
    if (neu == null || !mounted) return;
    setState(() {
      _kacheln = [..._kacheln, neu];
      _reihenfolge = [..._reihenfolge, neu.id];
    });
    await _speichern();
    // Die neue Kachel kann Nachrichten brauchen, die noch keiner geholt hat.
    await _datenLaden();
  }

  Future<void> _kachelBearbeiten(CustomTile kachel) async {
    final geaendert =
        await showTileEditor(context, vorhanden: kachel, daten: _daten);
    if (geaendert == null || !mounted) return;
    setState(() {
      _kacheln =
          _kacheln.map((k) => k.id == kachel.id ? geaendert : k).toList();
    });
    await _speichern();
    await _datenLaden();
  }

  Future<void> _kachelLoeschen(CustomTile kachel) async {
    setState(() {
      _kacheln = _kacheln.where((k) => k.id != kachel.id).toList();
      _reihenfolge = _reihenfolge.where((k) => k != kachel.id).toList();
    });
    await _speichern();
  }

  Future<void> _verschieben(String von, String nach) async {
    final liste = List<String>.from(_reihenfolge);
    final a = liste.indexOf(von);
    final b = liste.indexOf(nach);
    if (a < 0 || b < 0 || a == b) return;
    liste.removeAt(a);
    liste.insert(b, von);
    setState(() => _reihenfolge = liste);
    await _speichern();
  }

  @override
  Widget build(BuildContext context) {
    if (_laedt) return const Center(child: CircularProgressIndicator());

    final sichtbar = _reihenfolge
        .where((k) => !_versteckt.contains(k))
        .map((k) => _kacheln.where((t) => t.id == k).firstOrNull)
        .whereType<CustomTile>()
        .toList();

    // Die Leiste steht nur da, wo sie etwas bedeutet: auf einer Seite ohne
    // Terminkachel waere sie ein Schalter ohne Wirkung.
    final zeigtTermine = TileCatalog.zeigtTermine(sichtbar);

    return Stack(
      children: [
        Column(
          children: [
            if (zeigtTermine)
              KalenderLeiste(
                einstellungen: _einstellungen,
                onGeaendert: (neu) async {
                  setState(() => _einstellungen = neu);
                  await _speichern();
                  await _datenLaden();
                },
              ),
            Expanded(child: _raster(sichtbar)),
          ],
        ),
        if (_fehler != null)
          Positioned(
            left: 20, right: 20, top: 12,
            child: Material(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(_fehler!),
              ),
            ),
          ),
        Positioned(
          right: 24,
          bottom: 24,
          child: Row(
            children: [
              if (_bearbeiten) ...[
                // Beschriftet statt nur bebildert: zwei gleich grosse
                // runde Knoepfe nebeneinander liessen offen, dass der eine
                // anlegt und der andere nur filtert.
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FloatingActionButton.extended(
                    heroTag: 'kalender',
                    tooltip: 'Nur festlegen, welche Kalender gezeigt werden',
                    onPressed: _kalenderWaehlen,
                    icon: const Icon(Icons.filter_alt_outlined, size: 26),
                    label: const Text('Kalender filtern',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FloatingActionButton.extended(
                    heroTag: 'neu',
                    tooltip: 'Eine neue Kachel auf diese Seite legen',
                    onPressed: _kachelHinzufuegen,
                    icon: const Icon(Icons.add_rounded, size: 28),
                    label: const Text('Kachel',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
              FloatingActionButton.large(
                heroTag: 'bearbeiten',
                onPressed: () => setState(() => _bearbeiten = !_bearbeiten),
                child: Icon(
                  _bearbeiten ? Icons.check_rounded : Icons.edit_outlined,
                  size: 30,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Die Kacheln der Seite.
  ///
  /// Eine einzelne Kachel bekommt die ganze Flaeche: eine Wochenansicht
  /// allein auf der Seite soll aussehen wie im Planner und nicht wie ein
  /// Kaertchen mit viel Weiss daneben.
  Widget _raster(List<CustomTile> sichtbar) {
    if (sichtbar.isEmpty) {
      return RefreshIndicator(onRefresh: _laden, child: _leer());
    }

    Widget karte(CustomTile k) => ReorderableTile(
          key: ValueKey(k.id),
          tileKey: k.id,
          enabled: _bearbeiten,
          onReorder: _verschieben,
          child: CustomTileCard(
            tile: k,
            data: _daten,
            arranging: _bearbeiten,
            onEdit: () => _kachelBearbeiten(k),
            onDelete: () => _kachelLoeschen(k),
            onGeaendert: _datenLaden,
          ),
        );

    // Kalenderansichten bekommen die volle Breite und viel Hoehe. In eine
    // Rasterspalte gequetscht ist ein Wochenraster unlesbar – sieben Spalten
    // und ein Dutzend Stunden brauchen Platz, sonst ist es genau die
    // "kleine Karte", die niemand haben wollte.
    final kalender = sichtbar.where(_istKalender).toList();
    final rest = sichtbar.where((k) => !_istKalender(k)).toList();

    return RefreshIndicator(
      onRefresh: _laden,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Zwei Spalten statt drei: lieber grosse Kacheln als viele. Auf
          // einem Geraet an der Wand zaehlt Lesbarkeit mehr als Dichte.
          final spalten = constraints.maxWidth >= 1100 ? 3 : 2;

          // Liegt nichts anderes auf der Seite, fuellt der Kalender sie ganz.
          final kalenderHoehe = rest.isEmpty
              ? (constraints.maxHeight - 130).clamp(360.0, double.infinity)
              : (constraints.maxHeight * 0.62).clamp(360.0, 720.0);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            children: [
              for (final k in kalender)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: SizedBox(height: kalenderHoehe, child: karte(k)),
                ),
              if (rest.isNotEmpty)
                GridView.count(
                  // Im ListView: eigene Hoehe statt eigenem Scrollen.
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: spalten,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 1.35,
                  children: [for (final k in rest) karte(k)],
                ),
            ],
          );
        },
      ),
    );
  }

  /// Zeigt diese Kachel einen Kalender – also ein Wochen- oder Monatsraster?
  static bool _istKalender(CustomTile k) =>
      TileCatalog.byKey(k.source)?.shape == TileShape.schedule;

  Widget _leer() => ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.dashboard_customize_outlined,
              size: 72, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 20),
          const Text(
            'Diese Seite ist noch leer.\n'
            'Auf den Stift tippen, dann „Kachel" — für einen Kalender die '
            'Monatsansicht wählen.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, height: 1.4),
          ),
        ],
      );
}

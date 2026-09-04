import 'dart:async';
import 'package:flutter/material.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/tabs/dashboard/custom/tile_catalog.dart';
import 'package:productivity/dataservice/rechte_zuordnung.dart';
import 'package:productivity/provider/permission_provider.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/task.dart';
import 'package:productivity/dataclasses/pantry_extras.dart';
import 'package:productivity/dataclasses/pantry_item.dart';
import 'package:productivity/dataclasses/ingredient.dart';
import 'package:productivity/dataclasses/time_entry.dart';
import 'package:productivity/dataclasses/meal_plan.dart';
import 'package:productivity/dataclasses/recipe.dart';
import 'package:productivity/dataclasses/shop.dart';
import 'package:productivity/dataclasses/shopping_list_item_price.dart';
import 'package:productivity/dataservice/task_service.dart';
import 'package:productivity/dataservice/shopping_list_service.dart';
import 'package:productivity/dataservice/pantry_service.dart';
import 'package:productivity/dataservice/ingredient_service.dart';
import 'package:productivity/dataservice/time_entry_service.dart';
import 'package:productivity/dataservice/meal_plan_service.dart';
import 'package:productivity/dataservice/recipe_service.dart';
import 'package:productivity/dataservice/shop_service.dart';
import 'package:productivity/dataservice/shopping_list_item_price_service.dart';
import 'package:productivity/tabs/dashboard/widgets/greeting_header.dart';
import 'package:productivity/tabs/dashboard/widgets/quick_actions.dart';
import 'package:productivity/tabs/dashboard/widgets/today_focus_card.dart';
import 'package:productivity/tabs/dashboard/widgets/tasks_widget.dart';
import 'package:productivity/tabs/dashboard/widgets/pantry_widget.dart';
import 'package:productivity/tabs/dashboard/widgets/time_widget.dart';
import 'package:productivity/tabs/dashboard/widgets/shopping_widget.dart';
import 'package:productivity/tabs/dashboard/widgets/mealplan_widget.dart';
import 'package:productivity/tabs/dashboard/widgets/journal_widget.dart';
import 'package:productivity/tabs/dashboard/widgets/notes_widget.dart';
import 'package:productivity/tabs/dashboard/widgets/today_agenda_widget.dart';
import 'package:productivity/tabs/dashboard/dashboard_prefs.dart';
import 'package:productivity/widgets/dashboard/collapsible_section.dart';
import 'package:productivity/widgets/dashboard/reorderable_tile.dart';
import 'package:productivity/widgets/platform_draggable.dart';
import 'package:productivity/tabs/dashboard/custom/custom_tile_card.dart';
import 'package:productivity/tabs/dashboard/custom/tile_editor.dart';
import 'package:productivity/tabs/dashboard/custom/tile_spec.dart';
import 'package:productivity/utils/snack.dart';
import 'package:productivity/dataservice/weather_service.dart';
import 'package:productivity/provider/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:productivity/dataclasses/note.dart';
import 'package:productivity/dataclasses/journal_entry.dart';
import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/dataservice/note_service.dart';
import 'package:productivity/dataservice/journal_service.dart';
import 'package:productivity/dataservice/journal_analysis_service.dart';
import 'package:productivity/dataservice/planner_service.dart';

class DashboardPage extends BasePage {
  const DashboardPage({super.key}) : super(title: 'Dashboard');

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
    ),
  ];

  @override
  Widget buildBody(BuildContext context) => const _DashboardContent();
}

class _DashboardContent extends StatefulWidget {
  const _DashboardContent();

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  // Data
  List<Task> _tasks = [];
  List<ShoppingListItem> _shoppingItems = [];
  List<PantryItem> _pantryItems = [];
  List<TimeEntry> _timeEntries = [];
  List<MealPlanEntry> _mealPlanEntries = [];
  List<Recipe> _recipes = [];
  List<Shop> _shops = [];
  Map<String, Ingredient> _ingredientMap = {};
  Map<String, List<ShoppingListItemPrice>> _pricesByItemId = {};
  List<Note> _notes = [];
  List<JournalEntry> _journalEntries = [];
  List<PlannerEntry> _plannerEntries = [];
  Map<String, dynamic> _sentimentStats = {};

  // Dashboard-Anpassung (Reihenfolge + ausgeblendete Kacheln)
  List<String> _widgetOrder =
      DashboardPrefs.defaultOrder(DashboardPrefs.keyDashboard);

  /// Solange an, lassen sich die Kacheln ziehen und bearbeiten.
  bool _arranging = false;

  /// Selbst zusammengestellte Kacheln.
  List<CustomTile> _customTiles = [];
  Set<String> _hidden = {};

  /// Bereiche, die dieser Nutzer nicht sehen darf. Ihre Kacheln werden
  /// ausgeblendet statt mit einer Fehlermeldung angezeigt – wer kein Recht
  /// auf den Vorrat hat, will nicht dauernd daran erinnert werden.
  Set<String> _gesperrteQuellen = {};

  // Wetter
  WeatherForecast? _weather;
  bool _weatherLoading = true;

  bool _loading = true;
  String? _error;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadLayout();
    _loadData();
    _loadWeather();
    // Auto-refresh every 60 seconds for live data
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _loadData(silent: true),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    if (mounted) setState(() => _weatherLoading = true);
    try {
      final city = context.read<SettingsProvider>().weatherCity;
      final w = await WeatherService.load(city: city);
      if (!mounted) return;
      setState(() {
        _weather = w;
        _weatherLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _weatherLoading = false);
    }
  }

  Future<void> _loadLayout() async {
    final layout = await DashboardPrefs.load(DashboardPrefs.keyDashboard);
    if (!mounted) return;
    setState(() {
      _widgetOrder = layout.order;
      _hidden = layout.hidden;
      _customTiles = layout.tiles;
    });
  }

  /// Verschiebt `from` an die Stelle von `to` und speichert sofort.
  Future<void> _moveTile(String from, String to) async {
    // Kopfkarten bleiben oben, Übersichtskacheln bleiben im Raster. Ein
    // Zug über die Grenze wäre technisch möglich, sähe aber falsch aus:
    // die Begrüßung ist auf volle Breite gebaut, ein Aufgabenkärtchen nicht.
    if (DashboardPrefs.istKopf(from) != DashboardPrefs.istKopf(to)) return;

    final order = List<String>.from(_widgetOrder);
    final alt = order.indexOf(from);
    final neu = order.indexOf(to);
    if (alt < 0 || neu < 0 || alt == neu) return;

    order.removeAt(alt);
    order.insert(neu, from);
    setState(() => _widgetOrder = order);

    await _persist(order, _hidden, _customTiles);
  }

  /// Speichert den ganzen Stand und meldet, wenn nur lokal gesichert wurde.
  Future<void> _persist(
    List<String> order,
    Set<String> hidden,
    List<CustomTile> tiles,
  ) async {
    final gespeichert = await DashboardPrefs.save(
      DashboardPrefs.keyDashboard, order, hidden, tiles: tiles);
    if (!mounted) return;
    if (!gespeichert) {
      // Lokal ist es gesichert, nur der Abgleich fehlt.
      showErrorSnack('Nur auf diesem Gerät gespeichert — Server nicht erreichbar');
    }
  }

  /// Legt eine eigene Kachel an und stellt sie nach oben.
  Future<void> _addCustomTile() async {
    final neu = await showTileEditor(context);
    if (neu == null || !mounted) return;
    final tiles = [..._customTiles, neu];
    final order = [neu.id, ..._widgetOrder];
    setState(() {
      _customTiles = tiles;
      _widgetOrder = order;
    });
    await _persist(order, _hidden, tiles);
  }

  Future<void> _editCustomTile(CustomTile tile) async {
    final geaendert = await showTileEditor(context, vorhanden: tile);
    if (geaendert == null || !mounted) return;
    final tiles =
        _customTiles.map((t) => t.id == tile.id ? geaendert : t).toList();
    setState(() => _customTiles = tiles);
    await _persist(_widgetOrder, _hidden, tiles);
  }

  Future<void> _deleteCustomTile(CustomTile tile) async {
    final tiles = _customTiles.where((t) => t.id != tile.id).toList();
    final order = _widgetOrder.where((k) => k != tile.id).toList();
    setState(() {
      _customTiles = tiles;
      _widgetOrder = order;
    });
    await _persist(order, _hidden, tiles);
  }

  Future<void> _openCustomize() async {
    final order = List<String>.from(_widgetOrder);
    final hidden = Set<String>.from(_hidden);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Dashboard anpassen'),
          content: SizedBox(
            width: double.maxFinite,
            height: 360,
            child: ReorderableListView(
              // onReorderItem korrigiert newI bereits um das entnommene Element,
              // der manuelle `newI--`-Ausgleich von onReorder entfaellt daher.
              onReorderItem: (oldI, newI) => setLocal(() {
                final k = order.removeAt(oldI);
                order.insert(newI, k);
              }),
              children: [
                for (final k in order)
                  ListTile(
                    key: ValueKey(k),
                    leading: const Icon(Icons.drag_handle),
                    title: Text(DashboardPrefs.labels[k] ?? k),
                    trailing: Switch(
                      value: !hidden.contains(k),
                      onChanged: (v) => setLocal(() {
                        if (v) {
                          hidden.remove(k);
                        } else {
                          hidden.add(k);
                        }
                      }),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Speichern')),
          ],
        ),
      ),
    );
    if (saved == true) {
      setState(() {
        _widgetOrder = order;
        _hidden = hidden;
      });
      await _persist(order, hidden, _customTiles);
    }
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    // Die Rechte des Nutzers, soweit die App sie kennt. Ein gesperrter
    // Bereich wird gar nicht erst abgefragt – das spart eine Anfrage, die
    // ohnehin nur 403 zurueckgaebe.
    final rechte = context.read<PermissionProvider>();
    final gesperrt = <String>{};
    var versucht = 0;
    var gescheitert = 0;

    /// Laedt eine Quelle fuer sich. Faellt sie aus, bleibt sie leer und die
    /// uebrigen Kacheln stehen trotzdem.
    ///
    /// Vorher hing alles in einem einzigen `Future.wait` mit einem `catch`
    /// aussen herum: ein 403 in einem Bereich hat die komplette Uebersicht
    /// abgerissen und durch eine Fehlermeldung ersetzt.
    Future<List<T>> hole<T>(String quelle, Future<List<T>> Function() laden) async {
      final noetig = rechtJeQuelle[quelle];
      if (noetig != null && !rechte.darf(noetig)) {
        gesperrt.add(quelle);
        return <T>[];
      }
      versucht++;
      try {
        return await laden();
      } catch (e) {
        if (ApiFehler.istVerboten(e)) {
          gesperrt.add(quelle);
        } else {
          gescheitert++;
        }
        return <T>[];
      }
    }

    try {
      final results = await Future.wait([
        hole('tasks', TaskService.loadAll), // 0
        hole('shopping', ShoppingListService.loadAll), // 1
        hole('pantry', PantryService.loadAll), // 2
        hole('ingredients', IngredientService.loadAll), // 3
        hole('time', TimeEntryService.loadAll), // 4
        hole('mealplan', MealPlanService.loadAll), // 5
        hole('recipes', RecipeService.loadAll), // 6
        hole('shops', ShopService.loadAll), // 7
        hole('notes', NoteService.loadAll), // 8
        hole('journal', JournalService.loadAll), // 9
        hole('planner', PlannerService.loadAll), // 10
      ]);

      Map<String, dynamic> sentimentStats = {};
      try {
        final now = DateTime.now();
        sentimentStats = await JournalAnalysisService.getSentimentStatistics(
          dateFrom: now.subtract(const Duration(days: 30)),
          dateTo: now,
        );
      } catch (_) {}

      final shoppingItems = results[1] as List<ShoppingListItem>;

      // Load prices for all shopping items in parallel (for cost estimation)
      final priceMap = <String, List<ShoppingListItemPrice>>{};
      await Future.wait(
        shoppingItems.where((i) => !i.isBought).map((item) async {
          try {
            final prices = await ShoppingListItemPriceService.loadByItemId(
              item.id,
            );
            priceMap[item.id] = prices;
          } catch (_) {
            priceMap[item.id] = [];
          }
        }),
      );

      if (!mounted) return;
      setState(() {
        _tasks = results[0] as List<Task>;
        _shoppingItems = shoppingItems;
        _pantryItems = results[2] as List<PantryItem>;
        final ingredients = results[3] as List<Ingredient>;
        _ingredientMap = {for (var i in ingredients) i.id: i};
        _timeEntries = results[4] as List<TimeEntry>;
        _mealPlanEntries = results[5] as List<MealPlanEntry>;
        _recipes = results[6] as List<Recipe>;
        _shops = results[7] as List<Shop>;
        _notes = results[8] as List<Note>;
        _journalEntries = results[9] as List<JournalEntry>;
        _plannerEntries = results[10] as List<PlannerEntry>;
        _pricesByItemId = priceMap;
        _sentimentStats = sentimentStats;
        _gesperrteQuellen = gesperrt;
        // Einzelne Ausfaelle lassen die uebrigen Kacheln stehen. Faellt aber
        // ALLES aus, was ueberhaupt versucht wurde, ist das kein leeres
        // Dashboard, sondern ein Server, der nicht antwortet – und das soll
        // dastehen statt einer stillen leeren Seite.
        _error = (versucht > 0 && gescheitert == versucht)
            ? 'Der Server ist gerade nicht erreichbar.'
            : null;
        _loading = false;
      });
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = 'Fehler beim Laden der Daten: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    if (_error != null) {
      return _ErrorView(error: _error!, onRetry: _loadData);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1200;
          final isTablet =
              constraints.maxWidth >= 600 && constraints.maxWidth < 1200;
          final padding = isDesktop ? 32.0 : 16.0;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1.-4. Kopfbereich – in der gespeicherten Reihenfolge
                  // und im Bearbeitungsmodus genauso verschiebbar wie die
                  // Kacheln darunter.
                  ..._buildKopf(),

                  // 5. Anpassbares Widget-Raster
                  CollapsibleSection(
                    sectionKey: 'dashboard.uebersicht',
                    title: 'Übersicht',
                    actions: [
                      if (_arranging)
                        IconButton(
                          icon: const Icon(Icons.add_rounded),
                          tooltip: 'Kachel hinzufügen',
                          onPressed: _addCustomTile,
                        ),
                      IconButton(
                        icon: Icon(_arranging
                            ? Icons.check_rounded
                            : Icons.edit_outlined),
                        tooltip: _arranging
                            ? 'Bearbeiten beenden'
                            : 'Dashboard bearbeiten',
                        isSelected: _arranging,
                        onPressed: () =>
                            setState(() => _arranging = !_arranging),
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune),
                        tooltip: 'Kacheln ein- und ausblenden',
                        onPressed: _openCustomize,
                      ),
                    ],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_arranging) ...[
                          Text(
                            usesDirectDrag
                                ? 'Kachel auf eine andere ziehen · + fügt eine neue hinzu.'
                                : 'Kachel gedrückt halten und ziehen · + fügt eine neue hinzu.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        _buildWidgetGrid(isDesktop, isTablet),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Zu welcher Datenquelle eine Kachel gehoert. Fuer eingebaute Kacheln
  /// ist der Schluessel schon der Bereich; eigene Kacheln verraten es ueber
  /// die Seite, auf die sie zeigen.
  String? _quelleDerKachel(String key, Map<String, Widget> byKey) {
    final eingebaut = quelleJeKachel[key];
    if (eingebaut != null) return eingebaut;
    final tile = _customTiles.where((t) => t.id == key).firstOrNull;
    if (tile == null) return null;
    final quelle = TileCatalog.byKey(tile.source);
    return quelle?.route == null ? null : _quelleZurRoute(quelle!.route!);
  }

  /// Route einer eigenen Kachel → Bereich. Beide Zuordnungen stehen in
  /// `rechte_zuordnung.dart`; hier wird nur der Umweg ueber das Recht
  /// gegangen, damit es nur eine Wahrheit gibt.
  String? _quelleZurRoute(String route) {
    final recht = rechtJeRoute[route];
    if (recht == null) return null;
    for (final eintrag in rechtJeQuelle.entries) {
      if (eintrag.value == recht) return eintrag.key;
    }
    return null;
  }

  /// Die Karten über der Übersicht, in gespeicherter Reihenfolge.
  List<Widget> _buildKopf() {
    final rechte = context.watch<PermissionProvider>();

    final byKey = <String, Widget>{
      'greeting': GreetingHeader(
        tasksDueToday: _getTasksDueToday().length,
        lowPantryItems: _getLowPantryItems().length,
        forecast: _weather,
        weatherLoading: _weatherLoading,
        onRefreshWeather: _loadWeather,
      ),
      'quickactions': const QuickActions(),
      'todayfocus': TodayFocusCard(
        tasksDueToday: _getTasksDueToday().length,
        timeTrackedToday: _getTimeTrackedToday(),
        todayMealPlan: _getTodayMealPlan(),
        recipes: _recipes,
        estimatedShoppingCost: _getEstimatedShoppingCost(),
      ),
      'agenda': TodayAgendaWidget(entries: _getTodayPlanner()),
    };

    // "Heutige Termine" ohne Planer-Recht wegzulassen ist dieselbe Regel
    // wie im Raster darunter.
    const rechtJeKopfkarte = {'agenda': 'planner:read'};

    final sichtbar = _widgetOrder.where((k) =>
        byKey.containsKey(k) &&
        !_hidden.contains(k) &&
        (rechtJeKopfkarte[k] == null || rechte.darf(rechtJeKopfkarte[k]!)));

    final ergebnis = <Widget>[];
    for (final k in sichtbar) {
      ergebnis.add(ReorderableTile(
        key: ValueKey('kopf_$k'),
        tileKey: k,
        enabled: _arranging,
        onReorder: _moveTile,
        child: byKey[k]!,
      ));
      ergebnis.add(const SizedBox(height: 16));
    }
    if (ergebnis.isNotEmpty) ergebnis.add(const SizedBox(height: 8));
    return ergebnis;
  }

  Widget _buildWidgetGrid(bool isDesktop, bool isTablet) {
    // Kachel je Schlüssel – Reihenfolge/Sichtbarkeit steuert der Nutzer.
    final byKey = <String, Widget>{
      'tasks': TasksWidget(tasks: _tasks, tasksDueToday: _getTasksDueToday()),
      'pantry': PantryWidget(
        pantryItems: _pantryItems,
        ingredientMap: _ingredientMap,
        lowItems: _getLowPantryItems(),
        expiringItems: _getExpiringPantryItems(),
      ),
      'time': TimeWidget(
        timeEntries: _timeEntries,
        timeTrackedToday: _getTimeTrackedToday(),
        timeTrackedThisWeek: _getTimeTrackedThisWeek(),
        activeEntry: _getActiveTimeEntry(),
      ),
      'shopping': ShoppingWidget(
        shoppingItems: _shoppingItems,
        ingredientMap: _ingredientMap,
        pricesByItemId: _pricesByItemId,
        shops: _shops,
        estimatedCost: _getEstimatedShoppingCost(),
        onItemBought: _onShoppingItemBought,
      ),
      'mealplan':
          MealplanWidget(mealPlanEntries: _mealPlanEntries, recipes: _recipes),
      'journal': JournalWidget(
        journalEntries: _journalEntries,
        averageSentiment: _sentimentStats['averageSentiment'] != null
            ? (_sentimentStats['averageSentiment'] as num).toDouble()
            : null,
        positiveCount:
            (_sentimentStats['distribution'] as Map?)?['positive'] ?? 0,
        neutralCount:
            (_sentimentStats['distribution'] as Map?)?['neutral'] ?? 0,
        negativeCount:
            (_sentimentStats['distribution'] as Map?)?['negative'] ?? 0,
        topTopics:
            (_sentimentStats['topTopics'] as List?)
                ?.map((t) => t as Map<String, dynamic>)
                .toList() ??
            [],
      ),
      'notes':
          NotesWidget(notes: _notes, onRefresh: () => _loadData(silent: true)),
    };

    // Eigene Kacheln in dieselbe Zuordnung legen – ab hier ist kein
    // Unterschied mehr zwischen fest eingebaut und selbst gebaut.
    final daten = DashboardData(
      tasks: _tasks,
      timeEntries: _timeEntries,
      plannerEntries: _plannerEntries,
      shoppingItems: _shoppingItems,
      pantryItems: _pantryItems,
      notes: _notes,
      journalEntries: _journalEntries,
      sentimentStats: _sentimentStats,
      ingredientMap: _ingredientMap,
    );
    for (final t in _customTiles) {
      byKey[t.id] = CustomTileCard(
        tile: t,
        data: daten,
        arranging: _arranging,
        onEdit: () => _editCustomTile(t),
        onDelete: () => _deleteCustomTile(t),
      );
    }

    final rechte = context.watch<PermissionProvider>();

    /// Eine Kachel faellt weg, wenn ihr Bereich gesperrt ist – egal ob das
    /// aus den Rechten hervorging oder erst die Antwort des Servers es
    /// gezeigt hat.
    bool erlaubt(String key) {
      final noetig = rechtJeKachel[key];
      if (noetig != null && !rechte.darf(noetig)) return false;
      final quelle = _quelleDerKachel(key, byKey);
      return quelle == null || !_gesperrteQuellen.contains(quelle);
    }

    final sichtbar = _widgetOrder
        .where((k) =>
            !DashboardPrefs.istKopf(k) &&
            !_hidden.contains(k) &&
            byKey.containsKey(k) &&
            erlaubt(k))
        .toList();

    final widgets = sichtbar
        .map((k) => ReorderableTile(
              key: ValueKey(k),
              tileKey: k,
              enabled: _arranging,
              onReorder: _moveTile,
              child: byKey[k]!,
            ) as Widget)
        .toList();

    if (widgets.isEmpty) {
      return const SizedBox.shrink();
    }

    if (isDesktop) {
      // 3 columns on desktop
      return _buildGrid(widgets, 3);
    } else if (isTablet) {
      // 2 columns on tablet
      return _buildGrid(widgets, 2);
    } else {
      // 1 column on mobile
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widgets
            .map(
              (w) =>
                  Padding(padding: const EdgeInsets.only(bottom: 16), child: w),
            )
            .toList(),
      );
    }
  }

  Widget _buildGrid(List<Widget> widgets, int columns) {
    final rows = <Widget>[];
    for (int i = 0; i < widgets.length; i += columns) {
      final rowWidgets = <Widget>[];
      for (int j = 0; j < columns; j++) {
        if (i + j < widgets.length) {
          rowWidgets.add(Expanded(child: widgets[i + j]));
          if (j < columns - 1 && i + j + 1 < widgets.length) {
            rowWidgets.add(const SizedBox(width: 16));
          }
        } else {
          rowWidgets.add(const Expanded(child: SizedBox.shrink()));
        }
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rowWidgets,
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  // ──── Data Helpers ───────────────────────────

  List<Task> _getTasksDueToday() {
    final today = DateTime.now();
    return _tasks
        .where(
          (t) =>
              t.dueDate != null &&
              t.dueDate!.year == today.year &&
              t.dueDate!.month == today.month &&
              t.dueDate!.day == today.day &&
              !t.completed,
        )
        .toList();
  }

  List<PantryItem> _getLowPantryItems() {
    return _pantryItems.where((i) => i.amount <= i.minAmount).toList();
  }

  List<PantryItem> _getExpiringPantryItems() {
    final now = DateTime.now();
    final inSevenDays = now.add(const Duration(days: 7));
    return _pantryItems
        .where(
          (i) =>
              i.expiryDate != null &&
              i.expiryDate!.isAfter(now.subtract(const Duration(days: 1))) &&
              i.expiryDate!.isBefore(inSevenDays),
        )
        .toList()
      ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
  }

  Duration _getTimeTrackedToday() {
    final today = DateTime.now();
    final todayEntries = _timeEntries.where(
      (e) =>
          e.date.year == today.year &&
          e.date.month == today.month &&
          e.date.day == today.day,
    );

    Duration total = Duration.zero;
    for (final entry in todayEntries) {
      if (entry.endTime != null) {
        total += entry.duration;
      }
    }
    return total;
  }

  Duration _getTimeTrackedThisWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfDay = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );

    Duration total = Duration.zero;
    for (final entry in _timeEntries) {
      if (entry.date.isAfter(startOfDay.subtract(const Duration(days: 1))) &&
          entry.endTime != null) {
        total += entry.duration;
      }
    }
    return total;
  }

  TimeEntry? _getActiveTimeEntry() {
    try {
      return _timeEntries.firstWhere((e) => e.endTime == null);
    } catch (_) {
      return null;
    }
  }

  List<PlannerEntry> _getTodayPlanner() {
    final t = DateTime.now();
    return _plannerEntries
        .where((e) =>
            e.scheduledAt.year == t.year &&
            e.scheduledAt.month == t.month &&
            e.scheduledAt.day == t.day)
        .toList();
  }

  List<MealPlanEntry> _getTodayMealPlan() {
    final today = DateTime.now();
    return _mealPlanEntries
        .where(
          (e) =>
              e.date.year == today.year &&
              e.date.month == today.month &&
              e.date.day == today.day,
        )
        .toList();
  }

  double _getEstimatedShoppingCost() {
    double total = 0;
    final openItems = _shoppingItems.where((i) => !i.isBought).toList();
    for (final item in openItems) {
      final prices = _pricesByItemId[item.id];
      if (prices != null && prices.isNotEmpty) {
        // Use the lowest price across shops
        final minPrice = prices
            .map((p) => p.price)
            .reduce((a, b) => a < b ? a : b);
        total += minPrice * item.amount;
      }
    }
    return total;
  }

  Future<void> _onShoppingItemBought(ShoppingListItem item) async {
    try {
      final updated = item.copyWith(isBought: true);
      await ShoppingListService.upsert(updated);
      _loadData(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: colors.error),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Erneut versuchen'),
            ),
          ],
        ),
      ),
    );
  }
}

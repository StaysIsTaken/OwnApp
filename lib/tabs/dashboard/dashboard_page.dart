import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
import 'package:productivity/dataclasses/note.dart';
import 'package:productivity/dataclasses/journal_entry.dart';
import 'package:productivity/dataservice/note_service.dart';
import 'package:productivity/dataservice/journal_service.dart';
import 'package:productivity/dataservice/journal_analysis_service.dart';

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
  Map<String, dynamic> _sentimentStats = {};

  bool _loading = true;
  String? _error;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        TaskService.loadAll(),          // 0
        ShoppingListService.loadAll(),  // 1
        PantryService.loadAll(),        // 2
        IngredientService.loadAll(),    // 3
        TimeEntryService.loadAll(),     // 4
        MealPlanService.loadAll(),      // 5
        RecipeService.loadAll(),        // 6
        ShopService.loadAll(),          // 7
        NoteService.loadAll(),          // 8
        JournalService.loadAll(),       // 9
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
            final prices = await ShoppingListItemPriceService.loadByItemId(item.id);
            priceMap[item.id] = prices;
          } catch (e) {
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
        _pricesByItemId = priceMap;
        _sentimentStats = sentimentStats;
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
      return _ErrorView(
        error: _error!,
        onRetry: _loadData,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1200;
          final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1200;
          final padding = isDesktop ? 32.0 : 16.0;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Greeting Header
                  GreetingHeader(
                    tasksDueToday: _getTasksDueToday().length,
                    lowPantryItems: _getLowPantryItems().length,
                  ),
                  const SizedBox(height: 20),

                  // 2. Quick Actions
                  const QuickActions(),
                  const SizedBox(height: 20),

                  // 3. Today Focus Card
                  TodayFocusCard(
                    tasksDueToday: _getTasksDueToday().length,
                    timeTrackedToday: _getTimeTrackedToday(),
                    todayMealPlan: _getTodayMealPlan(),
                    recipes: _recipes,
                    estimatedShoppingCost: _getEstimatedShoppingCost(),
                  ),
                  const SizedBox(height: 24),

                  // 4. Widgets Grid
                  _buildWidgetGrid(isDesktop, isTablet),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWidgetGrid(bool isDesktop, bool isTablet) {
    final widgets = <Widget>[
      TasksWidget(
        tasks: _tasks,
        tasksDueToday: _getTasksDueToday(),
      ),
      PantryWidget(
        pantryItems: _pantryItems,
        ingredientMap: _ingredientMap,
        lowItems: _getLowPantryItems(),
        expiringItems: _getExpiringPantryItems(),
      ),
      TimeWidget(
        timeEntries: _timeEntries,
        timeTrackedToday: _getTimeTrackedToday(),
        timeTrackedThisWeek: _getTimeTrackedThisWeek(),
        activeEntry: _getActiveTimeEntry(),
      ),
      ShoppingWidget(
        shoppingItems: _shoppingItems,
        ingredientMap: _ingredientMap,
        pricesByItemId: _pricesByItemId,
        shops: _shops,
        estimatedCost: _getEstimatedShoppingCost(),
        onItemBought: _onShoppingItemBought,
      ),
      MealplanWidget(
        mealPlanEntries: _mealPlanEntries,
        recipes: _recipes,
      ),
      JournalWidget(
        journalEntries: _journalEntries,
        averageSentiment: _sentimentStats['averageSentiment'] != null
            ? (_sentimentStats['averageSentiment'] as num).toDouble()
            : null,
        positiveCount: (_sentimentStats['distribution'] as Map?)?['positive'] ?? 0,
        neutralCount: (_sentimentStats['distribution'] as Map?)?['neutral'] ?? 0,
        negativeCount: (_sentimentStats['distribution'] as Map?)?['negative'] ?? 0,
        topTopics: (_sentimentStats['topTopics'] as List?)
                ?.map((t) => t as Map<String, dynamic>)
                .toList() ??
            [],
      ),
      NotesWidget(
        notes: _notes,
        onRefresh: () => _loadData(silent: true),
      ),
    ];

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
            .map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: w,
                ))
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
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rowWidgets,
          ),
        ),
      ));
    }
    return Column(children: rows);
  }

  // ──── Data Helpers ───────────────────────────

  List<Task> _getTasksDueToday() {
    final today = DateTime.now();
    return _tasks
        .where((t) =>
            t.dueDate != null &&
            t.dueDate!.year == today.year &&
            t.dueDate!.month == today.month &&
            t.dueDate!.day == today.day &&
            !t.completed)
        .toList();
  }

  List<PantryItem> _getLowPantryItems() {
    return _pantryItems.where((i) => i.amount <= i.minAmount).toList();
  }

  List<PantryItem> _getExpiringPantryItems() {
    final now = DateTime.now();
    final inSevenDays = now.add(const Duration(days: 7));
    return _pantryItems
        .where((i) =>
            i.expiryDate != null &&
            i.expiryDate!.isAfter(now.subtract(const Duration(days: 1))) &&
            i.expiryDate!.isBefore(inSevenDays))
        .toList()
      ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
  }

  Duration _getTimeTrackedToday() {
    final today = DateTime.now();
    final todayEntries = _timeEntries.where((e) =>
        e.date.year == today.year &&
        e.date.month == today.month &&
        e.date.day == today.day);

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
    final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

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

  List<MealPlanEntry> _getTodayMealPlan() {
    final today = DateTime.now();
    return _mealPlanEntries
        .where((e) =>
            e.date.year == today.year &&
            e.date.month == today.month &&
            e.date.day == today.day)
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
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

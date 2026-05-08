import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/task.dart';
import 'package:productivity/dataclasses/pantry_extras.dart';
import 'package:productivity/dataclasses/pantry_item.dart';
import 'package:productivity/dataclasses/ingredient.dart';
import 'package:productivity/dataservice/task_service.dart';
import 'package:productivity/dataservice/shopping_list_service.dart';
import 'package:productivity/dataservice/pantry_service.dart';
import 'package:productivity/dataservice/ingredient_service.dart';

class HomePage extends BasePage {
  const HomePage({super.key}) : super(title: 'Home');

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
    ),
  ];

  @override
  Widget buildBody(BuildContext context) => const _HomePageContent();
}

class _HomePageContent extends StatefulWidget {
  const _HomePageContent();

  @override
  State<_HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<_HomePageContent> {
  List<Task> _tasks = [];
  List<ShoppingListItem> _shoppingItems = [];
  List<PantryItem> _pantryItems = [];
  Map<String, Ingredient> _ingredientMap = {};

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        TaskService.loadAll(),
        ShoppingListService.loadAll(),
        PantryService.loadAll(),
        IngredientService.loadAll(),
      ]);

      if (!mounted) return;
      setState(() {
        _tasks = results[0] as List<Task>;
        _shoppingItems = results[1] as List<ShoppingListItem>;
        _pantryItems = results[2] as List<PantryItem>;
        final ingredients = results[3] as List<Ingredient>;
        _ingredientMap = {for (var i in ingredients) i.id: i};
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
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
    final text = Theme.of(context).textTheme;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Willkommen!', style: text.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Schnellzugriff zu Ihren wichtigsten Funktionen',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 32),

              // ── Dashboard Section ────────────────────
              Text('Übersicht', style: text.titleLarge),
              const SizedBox(height: 16),
              _buildTaskStatistics(colors, text),
              const SizedBox(height: 16),
              _buildTasksDueToday(colors, text),
              const SizedBox(height: 16),
              _buildOpenShoppingItems(colors, text),
              const SizedBox(height: 16),
              _buildLowPantryItems(colors, text),
              const SizedBox(height: 32),

              // Main Modules Section
              Text('Hauptmodule', style: text.titleLarge),
              const SizedBox(height: 12),
              _buildNavigationCard(
                context,
                icon: Icons.task_outlined,
                title: 'Tasks',
                description: 'Aufgaben im Kanban Board verwalten',
                route: AppRoutes.tasks,
                containerColor: colors.primaryContainer,
                iconColor: colors.onPrimaryContainer,
              ),
              const SizedBox(height: 12),
              _buildNavigationCard(
                context,
                icon: Icons.menu_book_outlined,
                title: 'Rezepte',
                description: 'Rezepte verwalten',
                route: AppRoutes.recipes,
                containerColor: colors.secondaryContainer,
                iconColor: colors.onSecondaryContainer,
              ),
              const SizedBox(height: 12),
              _buildNavigationCard(
                context,
                icon: Icons.kitchen_outlined,
                title: 'Vorrat',
                description: 'Lebensmittelbestand verwalten',
                route: AppRoutes.pantry,
                containerColor: colors.secondaryContainer.withAlpha(180),
                iconColor: colors.onSecondaryContainer,
              ),
              const SizedBox(height: 12),
              _buildNavigationCard(
                context,
                icon: Icons.shopping_cart_outlined,
                title: 'Einkaufsliste',
                description: 'Einkäufe planen',
                route: AppRoutes.shoppingList,
                containerColor: colors.secondaryContainer.withAlpha(160),
                iconColor: colors.onSecondaryContainer,
              ),
              const SizedBox(height: 12),
              _buildNavigationCard(
                context,
                icon: Icons.today_outlined,
                title: 'Speiseplan',
                description: 'Mahlzeiten planen',
                route: AppRoutes.mealPlan,
                containerColor: colors.tertiaryContainer,
                iconColor: colors.onTertiaryContainer,
              ),
              const SizedBox(height: 12),
              _buildNavigationCard(
                context,
                icon: Icons.schedule_outlined,
                title: 'Zeiterfassung',
                description: 'Arbeitszeiten erfassen',
                route: AppRoutes.time,
                containerColor: colors.tertiaryContainer.withAlpha(180),
                iconColor: colors.onTertiaryContainer,
              ),
              const SizedBox(height: 12),
              _buildNavigationCard(
                context,
                icon: Icons.chat_outlined,
                title: 'Chat',
                description: 'Nachrichten und Chats',
                route: AppRoutes.chat,
                containerColor: colors.tertiaryContainer.withAlpha(160),
                iconColor: colors.onTertiaryContainer,
              ),
              const SizedBox(height: 32),

              // Master Data Section
              Text('Stammdaten', style: text.titleLarge),
              const SizedBox(height: 12),
              _buildNavigationCard(
                context,
                icon: Icons.category_outlined,
                title: 'Kategorien',
                description: 'Rezeptkategorien verwalten',
                route: AppRoutes.categories,
                containerColor: colors.surface,
                iconColor: colors.primary,
                isMasterData: true,
              ),
              const SizedBox(height: 12),
              _buildNavigationCard(
                context,
                icon: Icons.local_fire_department_outlined,
                title: 'Zutaten',
                description: 'Verfügbare Zutaten definieren',
                route: AppRoutes.ingredients,
                containerColor: colors.surface,
                iconColor: colors.primary,
                isMasterData: true,
              ),
              const SizedBox(height: 12),
              _buildNavigationCard(
                context,
                icon: Icons.straighten_outlined,
                title: 'Maßeinheiten',
                description: 'Maßeinheiten verwalten',
                route: AppRoutes.units,
                containerColor: colors.surface,
                iconColor: colors.primary,
                isMasterData: true,
              ),
              const SizedBox(height: 12),
              _buildNavigationCard(
                context,
                icon: Icons.storage_outlined,
                title: 'Lagerorte',
                description: 'Lagerverwaltung konfigurieren',
                route: AppRoutes.storageLocations,
                containerColor: colors.surface,
                iconColor: colors.primary,
                isMasterData: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──── Dashboard Widgets ─────────────────────────────

  Widget _buildTaskStatistics(ColorScheme colors, TextTheme text) {
    final todoCount = _tasks.where((t) => t.kanbanState == 'todo').length;
    final inProgressCount = _tasks.where((t) => t.kanbanState == 'in_progress').length;
    final doneCount = _tasks.where((t) => t.kanbanState == 'done').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Task-Statistik', style: text.titleMedium),
            Text(
              'Gesamt: ${_tasks.length}',
              style: text.labelSmall?.copyWith(color: colors.outline),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                colors: colors,
                text: text,
                label: 'Zu tun',
                count: todoCount,
                bgColor: colors.errorContainer,
                textColor: colors.onErrorContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                colors: colors,
                text: text,
                label: 'In Arbeit',
                count: inProgressCount,
                bgColor: colors.secondaryContainer,
                textColor: colors.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                colors: colors,
                text: text,
                label: 'Fertig',
                count: doneCount,
                bgColor: colors.tertiaryContainer,
                textColor: colors.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required ColorScheme colors,
    required TextTheme text,
    required String label,
    required int count,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: text.headlineSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: text.labelSmall?.copyWith(color: textColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTasksDueToday(ColorScheme colors, TextTheme text) {
    final today = DateTime.now();
    final dueTodayTasks = _tasks.where((t) =>
        t.dueDate != null &&
        t.dueDate!.year == today.year &&
        t.dueDate!.month == today.month &&
        t.dueDate!.day == today.day &&
        !t.completed).toList();

    if (dueTodayTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.3),
        border: Border.all(color: colors.error.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_rounded, color: colors.error, size: 20),
              const SizedBox(width: 8),
              Text(
                'Heute fällig: ${dueTodayTasks.length}',
                style: text.titleMedium?.copyWith(color: colors.error),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...dueTodayTasks.take(3).map((task) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.circle, size: 8, color: colors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.title,
                    style: text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )),
          if (dueTodayTasks.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+${dueTodayTasks.length - 3} mehr',
                style: text.labelSmall?.copyWith(color: colors.error),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOpenShoppingItems(ColorScheme colors, TextTheme text) {
    final openItems = _shoppingItems.where((item) => !item.isBought).toList();

    if (openItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Noch zu kaufen: ${openItems.length}',
          style: text.titleMedium,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              ...openItems.take(5).map((item) {
                final ing = _ingredientMap[item.ingredientId];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Checkbox(
                        value: false,
                        onChanged: (value) async {
                          try {
                            final updated = item.copyWith(isBought: true);
                            await ShoppingListService.upsert(updated);
                            _loadDashboardData();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Fehler: $e')),
                              );
                            }
                          }
                        },
                      ),
                      Expanded(
                        child: Text(
                          ing?.name ?? 'Unbekannt',
                          style: text.bodySmall,
                        ),
                      ),
                      Text(
                        '${item.amount}',
                        style: text.labelSmall?.copyWith(color: colors.outline),
                      ),
                    ],
                  ),
                );
              }),
              if (openItems.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+${openItems.length - 5} weitere',
                    style: text.labelSmall?.copyWith(color: colors.outline),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLowPantryItems(ColorScheme colors, TextTheme text) {
    final lowItems = _pantryItems
        .where((item) => item.amount <= item.minAmount)
        .toList();

    if (lowItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Niedrige Vorräte: ${lowItems.length}',
          style: text.titleMedium,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              ...lowItems.take(4).map((item) {
                final ing = _ingredientMap[item.ingredientId];
                final isLow = item.amount < item.minAmount / 2;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        size: 16,
                        color: isLow ? colors.error : colors.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ing?.name ?? 'Unbekannt',
                              style: text.labelSmall,
                            ),
                            Text(
                              '${item.amount.toStringAsFixed(1)} / ${item.minAmount.toStringAsFixed(1)}',
                              style: text.labelSmall?.copyWith(
                                color: colors.outline,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (lowItems.length > 4)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+${lowItems.length - 4} weitere',
                    style: text.labelSmall?.copyWith(color: colors.outline),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ──── Navigation Card Widget ────────────────────────

  Widget _buildNavigationCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String route,
    required Color containerColor,
    required Color iconColor,
    bool isMasterData = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: isMasterData
                      ? Border.all(color: colors.outline, width: 1)
                      : null,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: text.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

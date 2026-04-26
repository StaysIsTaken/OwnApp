import 'package:flutter/material.dart';
import 'package:productivity/dataservice/category_service.dart';
import 'package:productivity/dataservice/ingredient_service.dart';
import 'package:productivity/dataservice/recipe_service.dart';
import 'package:productivity/dataservice/unit_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/category.dart';
import 'package:productivity/dataclasses/ingredient.dart';
import 'package:productivity/dataclasses/recipe.dart';
import 'package:productivity/dataclasses/unit.dart';
import 'package:productivity/tabs/recipes/manage_categories_page.dart';
import 'package:productivity/tabs/recipes/manage_ingredients_page.dart';
import 'package:productivity/tabs/recipes/manage_units_page.dart';
import 'package:productivity/tabs/recipes/recipe_form_page.dart';

// ─────────────────────────────────────────────
//  RecipesPage  –  main recipe list
// ─────────────────────────────────────────────
class RecipesPage extends BasePage {
  const RecipesPage({super.key}) : super(title: 'Rezepte');

  @override
  Widget buildBody(BuildContext context) => const _RecipesPageContent();

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      PopupMenuButton<String>(
        icon: const Icon(Icons.tune_outlined),
        tooltip: 'Verwalten',
        onSelected: (v) {
          Widget? page;
          switch (v) {
            case 'categories':
              page = const ManageCategoriesPage();
            case 'ingredients':
              page = const ManageIngredientsPage();
            case 'units':
              page = const ManageUnitsPage();
          }
          if (page != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'categories',
            child: ListTile(
              leading: Icon(Icons.category_outlined),
              title: Text('Kategorien'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: 'ingredients',
            child: ListTile(
              leading: Icon(Icons.eco_outlined),
              title: Text('Zutaten'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: 'units',
            child: ListTile(
              leading: Icon(Icons.straighten_outlined),
              title: Text('Einheiten'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    ];
  }
}

class _RecipesPageContent extends StatefulWidget {
  const _RecipesPageContent();

  @override
  State<_RecipesPageContent> createState() => _RecipesPageContentState();
}

class _RecipesPageContentState extends State<_RecipesPageContent> {
  List<Recipe> _recipes = [];
  List<Category> _categories = [];
  Map<String, Ingredient> _ingredientMap = {};
  Map<String, Unit> _unitMap = {};

  String _filterText = '';
  List<String> _filterCategoryIds = []; // empty = all
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      RecipeService.loadAll(),
      CategoryService.loadAll(),
      IngredientService.loadAll(),
      UnitService.loadAll(),
    ]);
    if (!mounted) return;
    setState(() {
      _recipes = results[0] as List<Recipe>;
      _categories = results[1] as List<Category>;
      _ingredientMap = {
        for (final i in results[2] as List<Ingredient>) i.id: i
      };
      _unitMap = {for (final u in results[3] as List<Unit>) u.id: u};
      _loading = false;
    });
  }

  List<Recipe> get _filtered {
    var list = List<Recipe>.from(_recipes);
    if (_filterText.isNotEmpty) {
      final q = _filterText.toLowerCase();
      list = list
          .where((r) => r.name.toLowerCase().contains(q))
          .toList();
    }
    if (_filterCategoryIds.isNotEmpty) {
      list = list
          .where((r) => r.categoryIds.any((cid) => _filterCategoryIds.contains(cid)))
          .toList();
    }
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<String> _categoryNames(List<String> ids) =>
      _categories.where((c) => ids.contains(c.id)).map((c) => c.name).toList();

  Future<void> _openForm({Recipe? recipe}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeFormPage(recipe: recipe),
      ),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final filtered = _filtered;

    return Stack(
      children: [
        Column(
          children: [
            // ── Search bar ────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Rezepte suchen…',
                  prefixIcon: const Icon(Icons.search_outlined),
                  suffixIcon: _filterText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              setState(() => _filterText = ''),
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => _filterText = v),
              ),
            ),

            // ── Category filter chips ─────────────────
            if (_categories.isNotEmpty)
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  children: [
                    _FilterChip(
                      label: 'Alle',
                      selected: _filterCategoryIds.isEmpty,
                      onTap: () =>
                          setState(() => _filterCategoryIds = []),
                    ),
                    ..._categories.map((c) {
                      final isSelected = _filterCategoryIds.contains(c.id);
                      return _FilterChip(
                        label: c.name,
                        selected: isSelected,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _filterCategoryIds.remove(c.id);
                            } else {
                              _filterCategoryIds.add(c.id);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),

            // ── Count label ───────────────────────────
            if (!_loading)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${filtered.length} Rezept${filtered.length != 1 ? 'e' : ''}',
                    style:
                        text.bodySmall?.copyWith(color: colors.outline),
                  ),
                ),
              ),

            // ── Recipe list ───────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.menu_book_outlined,
                                  size: 64,
                                  color: colors.outlineVariant),
                              const SizedBox(height: 12),
                              Text(
                                _filterText.isEmpty &&
                                        _filterCategoryIds.isEmpty
                                    ? 'Noch keine Rezepte vorhanden'
                                    : 'Keine Rezepte gefunden',
                                style: text.bodyMedium
                                    ?.copyWith(color: colors.outline),
                              ),
                              if (_filterText.isEmpty &&
                                  _filterCategoryIds.isEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Tippe auf + um ein Rezept anzulegen',
                                  style: text.bodySmall?.copyWith(
                                      color: colors.outlineVariant),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 88),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _RecipeCard(
                            recipe: filtered[i],
                            categoryNames:
                                _categoryNames(filtered[i].categoryIds),
                            ingredientMap: _ingredientMap,
                            unitMap: _unitMap,
                            onTap: () => _openForm(recipe: filtered[i]),
                          ),
                        ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            label: const Text('Neues Rezept'),
          ),
        ),
      ],
    );
  }
}

// ── Category filter chip ──────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? colors.onPrimary : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Recipe Card ───────────────────────────────────────────────────────────────
class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final List<String> categoryNames;
  final Map<String, Ingredient> ingredientMap;
  final Map<String, Unit> unitMap;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.categoryNames,
    required this.ingredientMap,
    required this.unitMap,
    required this.onTap,
  });

  String _fmtAmount(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(
                      Icons.menu_book_outlined,
                      size: 18,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.name,
                          style: text.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (categoryNames.isNotEmpty)
                          Text(categoryNames.join(', '),
                              style: text.bodySmall?.copyWith(
                                  color: colors.primary)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: colors.outline),
                ],
              ),

              // ── Description preview ───────────
              if (recipe.description != null &&
                  recipe.description!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  recipe.description!,
                  style: text.bodySmall?.copyWith(color: colors.outline),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // ── Ingredients summary ───────────
              if (recipe.ingredients.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: recipe.ingredients.take(5).map((ri) {
                    final ing = ingredientMap[ri.ingredientId];
                    final unit = unitMap[ri.unitId];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        '${_fmtAmount(ri.amount)} ${unit?.symbol ?? ''} ${ing?.name ?? ''}',
                        style: text.bodySmall,
                      ),
                    );
                  }).toList()
                    ..addAll(
                      recipe.ingredients.length > 5
                          ? [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSm),
                                ),
                                child: Text(
                                  '+${recipe.ingredients.length - 5} mehr',
                                  style: text.bodySmall,
                                ),
                              )
                            ]
                          : [],
                    ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

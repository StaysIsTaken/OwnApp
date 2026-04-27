import 'package:flutter/material.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/meal_plan.dart';
import 'package:productivity/dataclasses/recipe.dart';
import 'package:productivity/dataservice/meal_plan_service.dart';
import 'package:productivity/dataservice/recipe_service.dart';
import 'package:intl/intl.dart';

class MealPlanPage extends BasePage {
  const MealPlanPage({super.key}) : super(title: 'Essensplaner');

  @override
  Widget buildBody(BuildContext context) {
    return const _MealPlanList();
  }
}

class _MealPlanList extends StatefulWidget {
  const _MealPlanList();

  @override
  State<_MealPlanList> createState() => _MealPlanListState();
}

class _MealPlanListState extends State<_MealPlanList> {
  List<MealPlanEntry> _entries = [];
  List<Recipe> _recipes = [];
  Map<String, Recipe> _recipeMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        MealPlanService.loadAll(),
        RecipeService.loadAll(),
      ]);

      if (!mounted) return;
      setState(() {
        _entries = results[0] as List<MealPlanEntry>;
        _recipes = results[1] as List<Recipe>;
        _recipeMap = {for (var r in _recipes) r.id: r};
        _entries.sort((a, b) => a.date.compareTo(b.date));
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showEditDialog([MealPlanEntry? entry]) {
    String? selRecipeId = entry?.recipeId;
    String? selMealType = entry?.mealType ?? 'Mittagessen';
    DateTime selDate = entry?.date ?? DateTime.now();
    final servingsCtrl = TextEditingController(text: entry?.servings.toString() ?? '2');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(entry == null ? 'Essen planen' : 'Planung bearbeiten', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selRecipeId,
                decoration: const InputDecoration(labelText: 'Rezept'),
                items: _recipes.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
                onChanged: (v) => setDialogState(() => selRecipeId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selMealType,
                decoration: const InputDecoration(labelText: 'Mahlzeit'),
                items: ['Frühstück', 'Mittagessen', 'Abendessen', 'Snack']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setDialogState(() => selMealType = v),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Datum'),
                subtitle: Text(DateFormat('EEEE, dd.MM.yyyy').format(selDate)),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setDialogState(() => selDate = picked);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: servingsCtrl,
                decoration: const InputDecoration(labelText: 'Personen'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (entry != null)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await MealPlanService.delete(entry.id);
                        if (!mounted) return;
                        Navigator.pop(context);
                        _load();
                      },
                    ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
                  ElevatedButton(
                    onPressed: () async {
                      if (selRecipeId == null) return;
                      final newEntry = MealPlanEntry(
                        id: entry?.id ?? '',
                        recipeId: selRecipeId!,
                        date: selDate,
                        mealType: selMealType,
                        servings: int.tryParse(servingsCtrl.text) ?? 2,
                      );
                      await MealPlanService.upsert(newEntry);
                      if (!mounted) return;
                      Navigator.pop(context);
                      _load();
                    },
                    child: const Text('Speichern'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add),
      ),
      body: _entries.isEmpty
          ? const Center(child: Text('Noch kein Essen geplant.\nTippe auf +, um anzufangen!', textAlign: TextAlign.center))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _entries.length,
              itemBuilder: (context, i) {
                final entry = _entries[i];
                final recipe = _recipeMap[entry.recipeId];
                final showDateHeader = i == 0 || 
                    DateFormat('yyyy-MM-dd').format(_entries[i-1].date) != 
                    DateFormat('yyyy-MM-dd').format(entry.date);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDateHeader) ...[
                      if (i > 0) const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          _formatDate(entry.date),
                          style: text.titleMedium?.copyWith(color: colors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colors.outlineVariant.withOpacity(0.5)),
                      ),
                      child: ListTile(
                        leading: _getMealIcon(entry.mealType ?? '', colors),
                        title: Text(recipe?.name ?? 'Unbekanntes Rezept', style: text.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                        subtitle: Text('${entry.mealType} • ${entry.servings} Personen'),
                        trailing: const Icon(Icons.edit_outlined, size: 20),
                        onTap: () => _showEditDialog(entry),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = date.difference(today).inDays;
    if (diff == 0) return 'Heute';
    if (diff == 1) return 'Morgen';
    return DateFormat('EEEE, dd. MMMM', 'de_DE').format(date);
  }

  Widget _getMealIcon(String type, ColorScheme colors) {
    IconData icon;
    switch (type.toLowerCase()) {
      case 'frühstück': icon = Icons.coffee_outlined; break;
      case 'mittagessen': icon = Icons.lunch_dining_outlined; break;
      case 'abendessen': icon = Icons.dinner_dining_outlined; break;
      default: icon = Icons.restaurant_outlined;
    }
    return CircleAvatar(
      backgroundColor: colors.primaryContainer,
      child: Icon(icon, color: colors.onPrimaryContainer, size: 20),
    );
  }
}

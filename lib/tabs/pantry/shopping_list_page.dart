import 'package:flutter/material.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/pantry_extras.dart';
import 'package:productivity/dataclasses/ingredient.dart';
import 'package:productivity/dataclasses/unit.dart';
import 'package:productivity/dataservice/shopping_list_service.dart';
import 'package:productivity/dataservice/ingredient_service.dart';
import 'package:productivity/dataservice/unit_service.dart';

class ShoppingListPage extends BasePage {
  const ShoppingListPage({super.key}) : super(title: 'Einkaufsliste');

  @override
  Widget buildBody(BuildContext context) {
    return const _ShoppingList();
  }
}

class _ShoppingList extends StatefulWidget {
  const _ShoppingList();

  @override
  State<_ShoppingList> createState() => _ShoppingListState();
}

class _ShoppingListState extends State<_ShoppingList> {
  List<ShoppingListItem> _items = [];
  List<Ingredient> _ingredients = [];
  List<Unit> _units = [];
  Map<String, Ingredient> _ingredientMap = {};
  Map<String, Unit> _unitMap = {};
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
        ShoppingListService.loadAll(),
        IngredientService.loadAll(),
        UnitService.loadAll(),
      ]);

      if (!mounted) return;
      setState(() {
        _items = results[0] as List<ShoppingListItem>;
        _ingredients = results[1] as List<Ingredient>;
        _units = results[2] as List<Unit>;
        _ingredientMap = {for (var i in _ingredients) i.id: i};
        _unitMap = {for (var u in _units) u.id: u};
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(ShoppingListItem item) async {
    try {
      final updated = item.copyWith(isBought: !item.isBought);
      await ShoppingListService.upsert(updated);
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  void _showEditDialog([ShoppingListItem? item]) {
    String? selIngId = item?.ingredientId;
    String? selUnitId = item?.unitId;
    final qtyCtrl = TextEditingController(text: item?.amount.toString() ?? '1');
    final noteCtrl = TextEditingController(text: item?.note ?? '');

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
              Text(item == null ? 'Hinzufügen' : 'Bearbeiten', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selIngId,
                decoration: const InputDecoration(labelText: 'Zutat'),
                items: _ingredients.map((i) => DropdownMenuItem(value: i.id, child: Text(i.name))).toList(),
                onChanged: (v) {
                  setDialogState(() {
                    selIngId = v;
                    // Auto-select default unit
                    final ing = _ingredients.where((i) => i.id == v).firstOrNull;
                    if (ing?.defaultUnitId != null) {
                      selUnitId = ing!.defaultUnitId;
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      decoration: const InputDecoration(labelText: 'Menge'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selUnitId,
                      decoration: const InputDecoration(labelText: 'Einheit'),
                      items: _units.map((u) => DropdownMenuItem(value: u.id, child: Text(u.symbol))).toList(),
                      onChanged: (v) => setDialogState(() => selUnitId = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Notiz (optional)'),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (item != null)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await ShoppingListService.delete(item.id);
                        if (!mounted) return;
                        Navigator.pop(context);
                        _load();
                      },
                    ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
                  ElevatedButton(
                    onPressed: () async {
                      if (selIngId == null || selUnitId == null) return;
                      final newItem = ShoppingListItem(
                        id: item?.id ?? '',
                        ingredientId: selIngId!,
                        unitId: selUnitId!,
                        amount: double.tryParse(qtyCtrl.text) ?? 1,
                        isBought: item?.isBought ?? false,
                        note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
                      );
                      await ShoppingListService.upsert(newItem);
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

    final sorted = List<ShoppingListItem>.from(_items);
    sorted.sort((a, b) {
      if (a.isBought == b.isBought) return 0;
      return a.isBought ? 1 : -1;
    });

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add),
      ),
      // NO AppBar here, because BasePage already has one
      body: _items.isEmpty
          ? const Center(child: Text('Deine Einkaufsliste ist leer'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final item = sorted[i];
                final ing = _ingredientMap[item.ingredientId];
                final unit = _unitMap[item.unitId];

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: Checkbox(
                    value: item.isBought,
                    shape: const CircleBorder(),
                    onChanged: (_) => _toggle(item),
                  ),
                  title: Text(
                    ing?.name ?? 'Unbekannt',
                    style: text.bodyLarge?.copyWith(
                      decoration: item.isBought ? TextDecoration.lineThrough : null,
                      color: item.isBought ? colors.outline : null,
                      fontWeight: item.isBought ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: item.note != null ? Text(item.note!) : null,
                  trailing: Text(
                    '${item.amount} ${unit?.symbol ?? ''}',
                    style: text.bodyMedium?.copyWith(
                      color: item.isBought ? colors.outline : colors.primary,
                    ),
                  ),
                  onTap: () => _toggle(item),
                  onLongPress: () => _showEditDialog(item),
                );
              },
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/pantry_extras.dart';
import 'package:productivity/dataclasses/ingredient.dart';
import 'package:productivity/dataclasses/unit.dart';
import 'package:productivity/dataclasses/shop.dart';
import 'package:productivity/dataclasses/shopping_list_item_price.dart';
import 'package:productivity/dataservice/shopping_list_service.dart';
import 'package:productivity/dataservice/ingredient_service.dart';
import 'package:productivity/dataservice/unit_service.dart';
import 'package:productivity/dataservice/shop_service.dart';
import 'package:productivity/dataservice/shopping_list_item_price_service.dart';

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
  List<Shop> _shops = [];
  Map<String, Ingredient> _ingredientMap = {};
  Map<String, Unit> _unitMap = {};
  Map<String, Shop> _shopMap = {};
  // Map<itemId, List<prices>>
  Map<String, List<ShoppingListItemPrice>> _pricesByItemId = {};
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
        ShopService.loadAll(),
      ]);

      final items = results[0] as List<ShoppingListItem>;
      final ingredients = results[1] as List<Ingredient>;
      final units = results[2] as List<Unit>;
      final shops = results[3] as List<Shop>;

      // Load prices for all items in parallel
      final priceMap = <String, List<ShoppingListItemPrice>>{};
      await Future.wait(
        items.map((item) async {
          try {
            final prices = await ShoppingListItemPriceService.loadByItemId(
              item.id,
            );
            priceMap[item.id] = prices;
          } catch (e) {
            priceMap[item.id] = [];
          }
        }),
      );

      if (!mounted) return;
      setState(() {
        _items = items;
        _ingredients = ingredients;
        _units = units;
        _shops = shops;
        _ingredientMap = {for (var i in _ingredients) i.id: i};
        _unitMap = {for (var u in _units) u.id: u};
        _shopMap = {for (var s in _shops) s.id: s};
        _pricesByItemId = priceMap;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  Future<void> _createShop(String name) async {
    try {
      final newShop = Shop(id: '', name: name, createdAt: DateTime.now());
      final result = await ShopService.create(newShop);
      setState(() {
        _shops.add(result);
        _shopMap[result.id] = result;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Shop erstellt')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  Future<void> _deleteShop(String shopId) async {
    try {
      await ShopService.delete(shopId);
      setState(() {
        _shops.removeWhere((s) => s.id == shopId);
        _shopMap.remove(shopId);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Shop gelöscht')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  Future<void> _addPrice(String itemId, String shopId, double price) async {
    try {
      final newPrice = ShoppingListItemPrice(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        shoppingListItemId: itemId,
        shopId: shopId,
        price: price,
        date: DateTime.now(),
      );
      final result = await ShoppingListItemPriceService.create(newPrice);
      setState(() {
        if (_pricesByItemId[itemId] == null) {
          _pricesByItemId[itemId] = [];
        }
        _pricesByItemId[itemId]!.add(result);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preis hinzugefügt')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  Future<void> _deletePrice(String itemId, String priceId) async {
    try {
      await ShoppingListItemPriceService.delete(priceId);
      setState(() {
        if (_pricesByItemId[itemId] != null) {
          _pricesByItemId[itemId]!.removeWhere((p) => p.id == priceId);
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preis gelöscht')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  String? _getBestPriceShop(String itemId) {
    final prices = _pricesByItemId[itemId];
    if (prices == null || prices.isEmpty) return null;

    ShoppingListItemPrice bestPrice = prices[0];
    for (var price in prices) {
      if (price.price < bestPrice.price) {
        bestPrice = price;
      }
    }

    return _shopMap[bestPrice.shopId]?.name;
  }

  String? _getPriceRange(String itemId) {
    final prices = _pricesByItemId[itemId];
    if (prices == null || prices.isEmpty) return null;

    double minPrice = prices[0].price;
    double maxPrice = prices[0].price;

    for (var price in prices) {
      if (price.price < minPrice) minPrice = price.price;
      if (price.price > maxPrice) maxPrice = price.price;
    }

    if (minPrice == maxPrice) {
      return '€${minPrice.toStringAsFixed(2)}';
    }

    return '€${minPrice.toStringAsFixed(2)} - €${maxPrice.toStringAsFixed(2)}';
  }

  void _showShopManagementDialog() {
    final shopNameCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shops verwalten',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                if (_shops.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Keine Shops vorhanden',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bestehende Shops:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      ..._shops.map(
                        (shop) => ListTile(
                          title: Text(shop.name),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              await _deleteShop(shop.id);
                              setDialogState(() {});
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                Text(
                  'Neuen Shop hinzufügen',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: shopNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Shop Name',
                    hintText: 'z.B. EDEKA, Lidl, ...',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Schließen'),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (shopNameCtrl.text.isNotEmpty) {
                          _createShop(shopNameCtrl.text);
                          setDialogState(() {
                            shopNameCtrl.clear();
                          });
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Hinzufügen'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditDialog([ShoppingListItem? item]) {
    String? selIngId = item?.ingredientId;
    String? selUnitId = item?.unitId;
    final qtyCtrl = TextEditingController(text: item?.amount.toString() ?? '1');
    final noteCtrl = TextEditingController(text: item?.note ?? '');
    final priceCtrl = TextEditingController();
    String? selShopId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final prices = item != null ? (_pricesByItemId[item.id] ?? []) : [];

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item == null ? 'Hinzufügen' : 'Bearbeiten',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: selIngId,
                    decoration: const InputDecoration(labelText: 'Zutat'),
                    items: _ingredients
                        .map(
                          (i) => DropdownMenuItem(
                            value: i.id,
                            child: Text(i.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setDialogState(() {
                        selIngId = v;
                        // Auto-select default unit
                        final ing = _ingredients
                            .where((i) => i.id == v)
                            .firstOrNull;
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
                          initialValue: selUnitId,
                          decoration: const InputDecoration(
                            labelText: 'Einheit',
                          ),
                          items: _units
                              .map(
                                (u) => DropdownMenuItem(
                                  value: u.id,
                                  child: Text(u.symbol),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setDialogState(() => selUnitId = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notiz (optional)',
                    ),
                  ),
                  // Prices section (only for existing items)
                  if (item != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Preise verfolgen',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (prices.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...prices.map((price) {
                            final shop = _shopMap[price.shopId];
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${shop?.name ?? 'Unbekannt'}: €${price.price.toStringAsFixed(2)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 16),
                                    onPressed: () async {
                                      await _deletePrice(item.id, price.id);
                                      setDialogState(() {});
                                    },
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 12),
                        ],
                      ),
                    // Add new price
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selShopId,
                            decoration: const InputDecoration(
                              labelText: 'Shop',
                            ),
                            items: _shops
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s.id,
                                    child: Text(s.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => selShopId = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Preis €',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_shops.isEmpty)
                      Text(
                        'Keine Shops konfiguriert. Bitte Shops hinzufügen.',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (selShopId != null && priceCtrl.text.isNotEmpty) {
                            final price = double.tryParse(priceCtrl.text) ?? 0;
                            if (price > 0) {
                              await _addPrice(item.id, selShopId!, price);
                              setDialogState(() {
                                priceCtrl.clear();
                                selShopId = null;
                              });
                            }
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Preis hinzufügen'),
                      ),
                  ],
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
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Abbrechen'),
                      ),
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
          );
        },
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            onPressed: _showShopManagementDialog,
            tooltip: 'Shops verwalten',
            heroTag: 'manage-shops',
            child: const Icon(Icons.store),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () => _showEditDialog(),
            heroTag: 'add-item',
            child: const Icon(Icons.add),
          ),
        ],
      ),
      // NO AppBar here, because BasePage already has one
      body: _items.isEmpty
          ? const Center(child: Text('Deine Einkaufsliste ist leer'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final item = sorted[i];
                final ing = _ingredientMap[item.ingredientId];
                final unit = _unitMap[item.unitId];
                final priceRange = _getPriceRange(item.id);
                final bestPriceShop = _getBestPriceShop(item.id);

                return Dismissible(
                  key: Key(item.id),
                  direction: DismissDirection.horizontal,
                  background: Container(
                    color: colors.error,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 16),
                    child: Icon(Icons.delete, color: colors.onError),
                  ),
                  secondaryBackground: Container(
                    color: colors.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: Icon(Icons.delete, color: colors.onError),
                  ),
                  onDismissed: (direction) async {
                    try {
                      await ShoppingListService.delete(item.id);
                      _load();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Einkaufslisteneintrag gelöscht',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Fehler beim Löschen: $e')),
                        );
                        _load();
                      }
                    }
                  },
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: Checkbox(
                      value: item.isBought,
                      shape: const CircleBorder(),
                      onChanged: (_) => _toggle(item),
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ing?.name ?? 'Unbekannt',
                          style: text.bodyLarge?.copyWith(
                            decoration: item.isBought
                                ? TextDecoration.lineThrough
                                : null,
                            color: item.isBought ? colors.outline : null,
                            fontWeight: item.isBought
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                        if (priceRange != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                priceRange,
                                style: text.labelSmall?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (bestPriceShop != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.secondaryContainer.withValues(
                                      alpha: 0.5,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Best: $bestPriceShop',
                                    style: text.labelSmall?.copyWith(
                                      color: colors.secondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                        if (item.note != null && item.note!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.note!,
                            style: text.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: Text(
                      '${item.amount} ${unit?.symbol ?? ''}',
                      style: text.bodyMedium?.copyWith(
                        color: item.isBought ? colors.outline : colors.primary,
                      ),
                    ),
                    onTap: () => _toggle(item),
                    onLongPress: () => _showEditDialog(item),
                  ),
                );
              },
            ),
    );
  }
}

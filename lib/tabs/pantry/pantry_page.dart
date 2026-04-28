import 'package:flutter/material.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/pantry_item.dart';
import 'package:productivity/dataclasses/pantry_extras.dart';
import 'package:productivity/dataclasses/ingredient.dart';
import 'package:productivity/dataclasses/unit.dart';
import 'package:productivity/dataservice/pantry_service.dart';
import 'package:productivity/dataservice/ingredient_service.dart';
import 'package:productivity/dataservice/unit_service.dart';
import 'package:intl/intl.dart';

class PantryPage extends BasePage {
  const PantryPage({super.key}) : super(title: 'Vorräte');

  @override
  Widget buildBody(BuildContext context) {
    return const _PantryList();
  }
}

class _PantryList extends StatefulWidget {
  const _PantryList();

  @override
  State<_PantryList> createState() => _PantryListState();
}

class _PantryListState extends State<_PantryList> {
  List<PantryItem> _items = [];
  List<StorageLocation> _locations = [];
  List<Ingredient> _ingredients = [];
  List<Unit> _units = [];
  Map<String, Ingredient> _ingredientMap = {};
  Map<String, Unit> _unitMap = {};

  String _filterText = '';
  String? _filterLocationId;
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
        PantryService.loadAll(),
        PantryService.loadLocations(),
        IngredientService.loadAll(),
        UnitService.loadAll(),
      ]);

      if (!mounted) return;
      setState(() {
        _items = results[0] as List<PantryItem>;
        _locations = results[1] as List<StorageLocation>;
        _ingredients = results[2] as List<Ingredient>;
        _units = results[3] as List<Unit>;
        _ingredientMap = {for (var i in _ingredients) i.id: i};
        _unitMap = {for (var u in _units) u.id: u};
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<PantryItem> get _filtered {
    var list = _items.where((item) {
      final ing = _ingredientMap[item.ingredientId];
      if (ing == null) return false;
      return ing.name.toLowerCase().contains(_filterText.toLowerCase());
    }).toList();

    if (_filterLocationId != null) {
      list = list
          .where((i) => i.storageLocationId == _filterLocationId)
          .toList();
    }
    return list;
  }

  Future<void> _updateQuantity(PantryItem item, double delta) async {
    try {
      final updated = item.copyWith(
        amount: (item.amount + delta).clamp(0, 999999),
      );
      await PantryService.upsert(updated);
      _load();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  void _showEditDialog([PantryItem? item]) {
    if (_ingredients.isEmpty || _units.isEmpty || _locations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bitte zuerst Zutaten, Einheiten und Lagerorte anlegen!',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? selIngId = item?.ingredientId;
    if (selIngId != null && !_ingredients.any((i) => i.id == selIngId))
      selIngId = null;

    String? selUnitId = item?.unitId;
    if (selUnitId != null && !_units.any((u) => u.id == selUnitId))
      selUnitId = null;

    String? selLocId = item?.storageLocationId;
    if (selLocId != null && !_locations.any((l) => l.id == selLocId))
      selLocId = null;
    final qtyCtrl = TextEditingController(text: item?.amount.toString() ?? '1');
    final minQtyCtrl = TextEditingController(
      text: item?.minAmount.toString() ?? '0',
    );
    DateTime? selExpiry = item?.expiryDate;

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
              children: [
                Text(
                  item == null ? 'Neuer Vorrat' : 'Vorrat bearbeiten',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: selIngId,
                  decoration: const InputDecoration(labelText: 'Zutat'),
                  items: _ingredients
                      .map(
                        (i) =>
                            DropdownMenuItem(value: i.id, child: Text(i.name)),
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
                        value: selUnitId,
                        decoration: const InputDecoration(labelText: 'Einheit'),
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
                DropdownButtonFormField<String>(
                  value: selLocId,
                  decoration: const InputDecoration(labelText: 'Lagerort'),
                  items: _locations
                      .map(
                        (l) =>
                            DropdownMenuItem(value: l.id, child: Text(l.name)),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => selLocId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minQtyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mindestmenge (für Einkauf)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Haltbarkeit'),
                  subtitle: Text(
                    selExpiry == null
                        ? 'Nicht gesetzt'
                        : DateFormat('dd.MM.yyyy').format(selExpiry!),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selExpiry ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null)
                      setDialogState(() => selExpiry = picked);
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (item != null)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await PantryService.delete(item.id);
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
                        if (selIngId == null ||
                            selUnitId == null ||
                            selLocId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Zutat, Einheit und Lagerort sind Pflichtfelder.',
                              ),
                            ),
                          );
                          return;
                        }
                        final newItem = PantryItem(
                          id: item?.id ?? '',
                          ingredientId: selIngId!,
                          unitId: selUnitId!,
                          storageLocationId: selLocId!,
                          amount: double.tryParse(qtyCtrl.text) ?? 1,
                          minAmount: double.tryParse(minQtyCtrl.text) ?? 0,
                          expiryDate: selExpiry,
                          updatedAt: DateTime.now(),
                        );
                        await PantryService.upsert(newItem);
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (_loading) return const Center(child: CircularProgressIndicator());

    final filtered = _filtered;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // --- Search & Filter ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Vorräte suchen...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: colors.surfaceVariant.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _filterText = v),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Alle'),
                        selected: _filterLocationId == null,
                        onSelected: (_) =>
                            setState(() => _filterLocationId = null),
                      ),
                      const SizedBox(width: 8),
                      ..._locations.map(
                        (loc) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(loc.name),
                            selected: _filterLocationId == loc.id,
                            onSelected: (s) => setState(
                              () => _filterLocationId = s ? loc.id : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- List ---
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'Keine Vorräte gefunden',
                      style: text.bodyLarge,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final item = filtered[i];
                      final ing = _ingredientMap[item.ingredientId];
                      final unit = _unitMap[item.unitId];
                      final loc = _locations
                          .where((l) => l.id == item.storageLocationId)
                          .firstOrNull;

                      return GestureDetector(
                        onTap: () => _showEditDialog(item),
                        child: _PantryCard(
                          item: item,
                          ingredient: ing,
                          unit: unit,
                          location: loc,
                          onAdd: () => _updateQuantity(item, 1),
                          onRemove: () => _updateQuantity(item, -1),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PantryCard extends StatelessWidget {
  final PantryItem item;
  final Ingredient? ingredient;
  final Unit? unit;
  final StorageLocation? location;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _PantryCard({
    required this.item,
    this.ingredient,
    this.unit,
    this.location,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final isLow = item.minAmount > 0 && item.amount < item.minAmount;
    final isExpired =
        item.expiryDate != null && item.expiryDate!.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ingredient?.name ?? 'Unbekannt',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (location != null)
                    Text(
                      location!.name,
                      style: text.bodySmall?.copyWith(color: colors.outline),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${item.amount} ${unit?.symbol ?? ''}',
                        style: text.bodyLarge?.copyWith(
                          color: isLow ? colors.error : colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (item.minAmount > 0)
                        Text(
                          ' / min. ${item.minAmount}',
                          style: text.bodySmall?.copyWith(
                            color: colors.outline,
                          ),
                        ),
                    ],
                  ),
                  if (item.expiryDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Haltbar bis: ${DateFormat('dd.MM.yyyy').format(item.expiryDate!)}',
                        style: text.labelSmall?.copyWith(
                          color: isExpired ? colors.error : colors.outline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove),
                ),
                IconButton.filledTonal(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:productivity/dataservice/category_service.dart';
import 'package:productivity/dataservice/ingredient_service.dart';
import 'package:productivity/dataservice/recipe_service.dart';
import 'package:productivity/dataservice/unit_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/category.dart';
import 'package:productivity/dataclasses/ingredient.dart';
import 'package:productivity/dataclasses/recipe.dart';
import 'package:productivity/dataclasses/recipe_ingredient.dart';
import 'package:productivity/dataclasses/unit.dart';

// ─────────────────────────────────────────────
//  RecipeFormPage  –  create / edit a recipe
// ─────────────────────────────────────────────
class RecipeFormPage extends StatefulWidget {
  /// Pass an existing recipe to edit it; null to create a new one.
  final Recipe? recipe;

  const RecipeFormPage({super.key, this.recipe});

  @override
  State<RecipeFormPage> createState() => _RecipeFormPageState();
}

class _RecipeFormPageState extends State<RecipeFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;

  List<String> _selectedCategoryIds = [];
  List<_IngredientEntry> _entries = [];

  List<Category> _categories = [];
  List<Ingredient> _ingredients = [];
  List<Unit> _units = [];

  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.recipe != null;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _descCtrl = TextEditingController(text: r?.description ?? '');
    _selectedCategoryIds = List<String>.from(r?.categoryIds ?? []);
    _entries = r?.ingredients
            .map((ri) => _IngredientEntry(
                  id: ri.id,
                  ingredientId: ri.ingredientId,
                  unitId: ri.unitId,
                  amount: ri.amount,
                ))
            .toList() ??
        [];
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      CategoryService.loadAll(),
      IngredientService.loadAll(),
      UnitService.loadAll(),
    ]);
    if (!mounted) return;
    setState(() {
      _categories = results[0] as List<Category>;
      _ingredients = results[1] as List<Ingredient>;
      _units = results[2] as List<Unit>;
      _loading = false;
    });
  }

  Map<String, Ingredient> get _ingredientMap =>
      {for (final i in _ingredients) i.id: i};
  Map<String, Unit> get _unitMap => {for (final u in _units) u.id: u};

  String _fmtAmount(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final recipe = Recipe(
      id: widget.recipe?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      categoryIds: _selectedCategoryIds,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      ingredients: _entries
          .map((e) => RecipeIngredient(
                id: e.id,
                ingredientId: e.ingredientId,
                unitId: e.unitId,
                amount: e.amount,
              ))
          .toList(),
    );

    await RecipeService.upsert(recipe);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _deleteRecipe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rezept löschen?'),
        content: Text('„${widget.recipe!.name}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await RecipeService.delete(widget.recipe!.id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  void _openAddIngredient({int? editIndex}) {
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte zuerst Zutaten unter „Zutaten verwalten" anlegen.'),
        ),
      );
      return;
    }
    if (_units.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte zuerst Einheiten unter „Einheiten verwalten" anlegen.'),
        ),
      );
      return;
    }

    final existing = editIndex != null ? _entries[editIndex] : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (_) => _AddIngredientSheet(
        ingredients: _ingredients,
        units: _units,
        initial: existing,
        onConfirm: (entry) {
          setState(() {
            if (editIndex != null) {
              _entries[editIndex] = entry;
            } else {
              _entries.add(entry);
            }
          });
        },
      ),
    );
  }

  void _removeIngredient(int index) {
    setState(() => _entries.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final imap = _ingredientMap;
    final umap = _unitMap;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Rezept bearbeiten' : 'Neues Rezept'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: Icon(Icons.delete_outline, color: colors.error),
              onPressed: _deleteRecipe,
              tooltip: 'Rezept löschen',
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    // ── Name ──────────────────────────────
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Rezeptname *',
                        hintText: 'z. B. Pfannkuchen',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name eingeben'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // ── Categories ────────────────────────
                    Text('Kategorien', style: text.titleMedium),
                    const SizedBox(height: 8),
                    _categories.isEmpty
                        ? Text('Keine Kategorien vorhanden.',
                            style: text.bodySmall?.copyWith(color: colors.outline))
                        : Wrap(
                            spacing: 8,
                            runSpacing: 0,
                            children: _categories.map((c) {
                              final isSelected = _selectedCategoryIds.contains(c.id);
                              return FilterChip(
                                label: Text(c.name),
                                labelStyle: TextStyle(
                                  color: isSelected ? colors.onPrimary : colors.onSurfaceVariant,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  fontSize: 13,
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedCategoryIds.add(c.id);
                                    } else {
                                      _selectedCategoryIds.remove(c.id);
                                    }
                                  });
                                },
                                backgroundColor: colors.surfaceVariant.withOpacity(0.3),
                                selectedColor: colors.primary,
                                checkmarkColor: colors.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: isSelected ? colors.primary : colors.outline.withOpacity(0.2),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              );
                            }).toList(),
                          ),
                    const SizedBox(height: 24),

                    // ── Description ───────────────────────
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Beschreibung (optional)',
                        hintText: 'Zubereitung, Tipps …',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Ingredients section ───────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Zutaten', style: text.titleLarge),
                        TextButton.icon(
                          onPressed: () => _openAddIngredient(),
                          icon: const Icon(Icons.add),
                          label: const Text('Hinzufügen'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_entries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Noch keine Zutaten hinzugefügt.',
                          style: text.bodySmall
                              ?.copyWith(color: colors.outline),
                        ),
                      )
                    else
                      ..._entries.asMap().entries.map((e) {
                        final idx = e.key;
                        final entry = e.value;
                        final ingredient = imap[entry.ingredientId];
                        final unit = umap[entry.unitId];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            title: Text(
                              ingredient?.name ?? '–',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${_fmtAmount(entry.amount)} ${unit?.symbol ?? ''}',
                              style: text.bodySmall,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit_outlined,
                                      color: colors.primary, size: 20),
                                  onPressed: () =>
                                      _openAddIngredient(editIndex: idx),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: colors.error, size: 20),
                                  onPressed: () => _removeIngredient(idx),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
      ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: Text(_isEdit ? 'Speichern' : 'Rezept anlegen'),
            ),
    );
  }
}

// ── Mutable entry for the form ────────────────────────────────────────────────
class _IngredientEntry {
  String? id;
  String ingredientId;
  String? unitId;
  double amount;

  _IngredientEntry({
    this.id,
    required this.ingredientId,
    this.unitId,
    required this.amount,
  });

  _IngredientEntry copyWith({
    String? id,
    String? ingredientId,
    String? unitId,
    double? amount,
  }) =>
      _IngredientEntry(
        id: id ?? this.id,
        ingredientId: ingredientId ?? this.ingredientId,
        unitId: unitId ?? this.unitId,
        amount: amount ?? this.amount,
      );
}

// ── Add / Edit Ingredient Sheet ────────────────────────────────────────────────
class _AddIngredientSheet extends StatefulWidget {
  final List<Ingredient> ingredients;
  final List<Unit> units;
  final _IngredientEntry? initial;
  final void Function(_IngredientEntry) onConfirm;

  const _AddIngredientSheet({
    required this.ingredients,
    required this.units,
    this.initial,
    required this.onConfirm,
  });

  @override
  State<_AddIngredientSheet> createState() => _AddIngredientSheetState();
}

class _AddIngredientSheetState extends State<_AddIngredientSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedIngredientId;
  late String? _selectedUnitId;
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _selectedIngredientId = init?.ingredientId ?? widget.ingredients.first.id;
    
    // Safety check for defaultUnitId
    final prefUnitId = init?.unitId ?? widget.ingredients.first.defaultUnitId;
    if (prefUnitId != null && widget.units.any((u) => u.id == prefUnitId)) {
      _selectedUnitId = prefUnitId;
    } else {
      _selectedUnitId = widget.units.isNotEmpty ? widget.units.first.id : null;
    }

    _amountCtrl = TextEditingController(
      text: init != null ? _fmtAmount(init.amount) : '',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  String _fmtAmount(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  void _onIngredientChanged(String? id) {
    if (id == null) return;
    final ingredient = widget.ingredients.firstWhere((i) => i.id == id);
    setState(() {
      _selectedIngredientId = id;
      
      // Update unit: use default unit if valid, otherwise fallback to the first unit in the list
      final defUnit = ingredient.defaultUnitId?.toString();
      if (defUnit != null && widget.units.any((u) => u.id.toString() == defUnit)) {
        _selectedUnitId = defUnit;
      } else if (widget.units.isNotEmpty) {
        _selectedUnitId = widget.units.first.id;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) return;

    widget.onConfirm(_IngredientEntry(
      ingredientId: _selectedIngredientId,
      unitId: _selectedUnitId,
      amount: amount,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isEdit = widget.initial != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isEdit ? 'Zutat bearbeiten' : 'Zutat hinzufügen',
              style: text.titleLarge,
            ),
            const SizedBox(height: 20),

            // ── Ingredient dropdown ───────────
            DropdownButtonFormField<String>(
              value: _selectedIngredientId,
              decoration: const InputDecoration(labelText: 'Zutat'),
              items: widget.ingredients
                  .map((i) =>
                      DropdownMenuItem(value: i.id, child: Text(i.name)))
                  .toList(),
              onChanged: _onIngredientChanged,
            ),
            const SizedBox(height: 12),

            // ── Amount + Unit row ─────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(labelText: 'Menge'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Menge eingeben';
                      final d = double.tryParse(v.replaceAll(',', '.'));
                      if (d == null || d <= 0) return 'Ungültige Menge';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String?>(
                    value: _selectedUnitId,
                    decoration: const InputDecoration(labelText: 'Einheit'),
                    items: widget.units
                        .map((u) => DropdownMenuItem<String?>(
                              value: u.id,
                              child: Text('${u.name} (${u.symbol})'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedUnitId = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _submit,
              child: Text(isEdit ? 'Übernehmen' : 'Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }
}

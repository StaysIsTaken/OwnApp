import 'package:flutter/material.dart';
import 'package:productivity/dataservice/ingredient_service.dart';
import 'package:productivity/dataservice/unit_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/models/ingredient.dart';
import 'package:productivity/models/unit.dart';
import 'package:productivity/widgets/manage_item_tile.dart';

// ─────────────────────────────────────────────
//  ManageIngredientsPage  –  CRUD for ingredients
// ─────────────────────────────────────────────
class ManageIngredientsPage extends StatefulWidget {
  const ManageIngredientsPage({super.key});

  @override
  State<ManageIngredientsPage> createState() => _ManageIngredientsPageState();
}

class _ManageIngredientsPageState extends State<ManageIngredientsPage> {
  List<Ingredient> _ingredients = [];
  List<Unit> _units = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      IngredientService.loadAll(),
      UnitService.loadAll(),
    ]);
    if (!mounted) return;
    setState(() {
      _ingredients = results[0] as List<Ingredient>;
      _units = results[1] as List<Unit>;
      _loading = false;
    });
  }

  String _unitName(String unitId) {
    final unit = _units.where((u) => u.id == unitId).firstOrNull;
    return unit != null ? '${unit.name} (${unit.symbol})' : '–';
  }

  Future<void> _confirmDelete(Ingredient ingredient) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zutat löschen?'),
        content: Text('„${ingredient.name}" wirklich löschen?'),
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
      await IngredientService.delete(ingredient.id);
      await _load();
    }
  }

  void _openForm({Ingredient? ingredient}) {
    if (_units.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte zuerst mindestens eine Einheit anlegen.'),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (_) => _IngredientForm(
        ingredient: ingredient,
        units: _units,
        onSave: (i) async {
          await IngredientService.upsert(i);
          await _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Zutaten verwalten')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _ingredients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.eco_outlined,
                            size: 64, color: colors.outlineVariant),
                        const SizedBox(height: 12),
                        Text('Noch keine Zutaten',
                            style: text.bodyMedium
                                ?.copyWith(color: colors.outline)),
                        const SizedBox(height: 6),
                        Text('Tippe auf + um eine Zutat anzulegen',
                            style: text.bodySmall
                                ?.copyWith(color: colors.outlineVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    itemCount: _ingredients.length,
                    itemBuilder: (_, i) => ManageItemTile(
                      title: _ingredients[i].name,
                      subtitle:
                          'Standard-Einheit: ${_unitName(_ingredients[i].defaultUnitId)}',
                      onEdit: () => _openForm(ingredient: _ingredients[i]),
                      onDelete: () => _confirmDelete(_ingredients[i]),
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Ingredient Form (Bottom Sheet) ────────────────────────────────────────────
class _IngredientForm extends StatefulWidget {
  final Ingredient? ingredient;
  final List<Unit> units;
  final Future<void> Function(Ingredient) onSave;

  const _IngredientForm({
    this.ingredient,
    required this.units,
    required this.onSave,
  });

  @override
  State<_IngredientForm> createState() => _IngredientFormState();
}

class _IngredientFormState extends State<_IngredientForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late String? _selectedUnitId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.ingredient?.name ?? '');
    _selectedUnitId = widget.ingredient?.defaultUnitId ??
        (widget.units.isNotEmpty ? widget.units.first.id : null);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUnitId == null) return;
    setState(() => _saving = true);

    final ingredient = Ingredient(
      id: widget.ingredient?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      defaultUnitId: _selectedUnitId!,
    );
    await widget.onSave(ingredient);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isEdit = widget.ingredient != null;

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
              isEdit ? 'Zutat bearbeiten' : 'Neue Zutat',
              style: text.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'z. B. Mehl',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name eingeben' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedUnitId,
              decoration: const InputDecoration(labelText: 'Standard-Einheit'),
              items: widget.units
                  .map((u) => DropdownMenuItem(
                        value: u.id,
                        child: Text('${u.name} (${u.symbol})'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedUnitId = v),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Einheit wählen' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isEdit ? 'Speichern' : 'Zutat anlegen'),
            ),
          ],
        ),
      ),
    );
  }
}

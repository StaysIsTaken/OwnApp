import 'package:flutter/material.dart';
import 'package:productivity/dataservice/category_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/models/category.dart';
import 'package:productivity/widgets/manage_item_tile.dart';

// ─────────────────────────────────────────────
//  ManageCategoriesPage  –  CRUD for categories
// ─────────────────────────────────────────────
class ManageCategoriesPage extends StatefulWidget {
  const ManageCategoriesPage({super.key});

  @override
  State<ManageCategoriesPage> createState() => _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends State<ManageCategoriesPage> {
  List<Category> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cats = await CategoryService.loadAll();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _loading = false;
    });
  }

  Future<void> _confirmDelete(Category cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kategorie löschen?'),
        content: Text('„${cat.name}" wirklich löschen?'),
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
      await CategoryService.delete(cat.id);
      await _load();
    }
  }

  void _openForm({Category? category}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (_) => _CategoryForm(
        category: category,
        onSave: (c) async {
          await CategoryService.upsert(c);
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
      appBar: AppBar(title: const Text('Kategorien verwalten')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _categories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.category_outlined,
                            size: 64, color: colors.outlineVariant),
                        const SizedBox(height: 12),
                        Text('Noch keine Kategorien',
                            style: text.bodyMedium
                                ?.copyWith(color: colors.outline)),
                        const SizedBox(height: 6),
                        Text('Tippe auf + um eine Kategorie anzulegen',
                            style: text.bodySmall
                                ?.copyWith(color: colors.outlineVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    itemCount: _categories.length,
                    itemBuilder: (_, i) => ManageItemTile(
                      title: _categories[i].name,
                      onEdit: () => _openForm(category: _categories[i]),
                      onDelete: () => _confirmDelete(_categories[i]),
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

// ── Category Form (Bottom Sheet) ──────────────────────────────────────────────
class _CategoryForm extends StatefulWidget {
  final Category? category;
  final Future<void> Function(Category) onSave;

  const _CategoryForm({this.category, required this.onSave});

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.category?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final cat = Category(
      id: widget.category?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
    );
    await widget.onSave(cat);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isEdit = widget.category != null;

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
              isEdit ? 'Kategorie bearbeiten' : 'Neue Kategorie',
              style: text.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'z. B. Frühstück',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name eingeben' : null,
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
                  : Text(isEdit ? 'Speichern' : 'Kategorie anlegen'),
            ),
          ],
        ),
      ),
    );
  }
}

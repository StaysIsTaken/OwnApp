import 'package:flutter/material.dart';
import 'package:productivity/dataservice/category_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/category.dart';

class ManageCategoriesPage extends BasePage {
  const ManageCategoriesPage({super.key}) : super(title: 'Kategorien verwalten');

  @override
  Widget buildBody(BuildContext context) => const _ManageCategoriesContent();
}

class _ManageCategoriesContent extends StatefulWidget {
  const _ManageCategoriesContent();

  @override
  State<_ManageCategoriesContent> createState() => _ManageCategoriesContentState();
}

class _ManageCategoriesContentState extends State<_ManageCategoriesContent> {
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
    final colors = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kategorie löschen?'),
        content: Text('Möchtest du „${cat.name}“ wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Löschen', style: TextStyle(color: colors.error)),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
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

    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        label: const Text('Kategorie'),
        icon: const Icon(Icons.add),
      ),
      body: _categories.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined, size: 64, color: colors.outline.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('Noch keine Kategorien', style: text.bodyLarge?.copyWith(color: colors.outline)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _categories.length,
              itemBuilder: (context, i) {
                final cat = _categories[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colors.outlineVariant.withOpacity(0.5)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: colors.primaryContainer,
                      child: Icon(Icons.label_outline, color: colors.onPrimaryContainer, size: 20),
                    ),
                    title: Text(cat.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _openForm(category: cat),
                          tooltip: 'Bearbeiten',
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 20, color: colors.error),
                          onPressed: () => _confirmDelete(cat),
                          tooltip: 'Löschen',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

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
      id: widget.category?.id ?? '',
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
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEdit ? 'Kategorie bearbeiten' : 'Neue Kategorie',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'z.B. Frühstück',
                filled: true,
                fillColor: colors.surfaceVariant.withOpacity(0.3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name eingeben' : null,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEdit ? 'Speichern' : 'Kategorie anlegen'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

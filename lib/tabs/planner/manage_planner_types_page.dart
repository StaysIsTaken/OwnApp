import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:productivity/dataclasses/planner_entry_type.dart';
import 'package:productivity/provider/planner_provider.dart';

class ManagePlannerTypesPage extends StatefulWidget {
  const ManagePlannerTypesPage({Key? key}) : super(key: key);

  @override
  State<ManagePlannerTypesPage> createState() => _ManagePlannerTypesPageState();
}

class _ManagePlannerTypesPageState extends State<ManagePlannerTypesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlannerProvider>().loadTypes();
    });
  }

  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planner-Typen')),
      body: Consumer<PlannerProvider>(
        builder: (context, provider, child) {
          final types = provider.types;
          if (types.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('Noch keine Typen angelegt',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: types.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final t = types[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getColorFromHex(t.color),
                    radius: 14,
                  ),
                  title: Text(t.name),
                  subtitle: Text(t.color),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showEditDialog(context, t),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(context, t),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmDelete(BuildContext context, PlannerEntryType type) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Typ löschen'),
        content: Text('Typ "${type.name}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context.read<PlannerProvider>().deletePlannerType(type.id);
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, PlannerEntryType? type) {
    showDialog(
      context: context,
      builder: (_) => _TypeEditDialog(type: type),
    );
  }
}

class _TypeEditDialog extends StatefulWidget {
  final PlannerEntryType? type;
  const _TypeEditDialog({this.type});

  @override
  State<_TypeEditDialog> createState() => _TypeEditDialogState();
}

class _TypeEditDialogState extends State<_TypeEditDialog> {
  late TextEditingController _nameController;
  late String _color;

  final List<String> _colors = [
    '#3B82F6', '#EF4444', '#10B981', '#F59E0B',
    '#8B5CF6', '#EC4899', '#06B6D4', '#6366F1',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.type?.name ?? '');
    _color = widget.type?.color ?? _colors[0];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.type == null ? 'Neuer Typ' : 'Typ bearbeiten'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Farbe', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _colors.map((c) {
              final isSelected = c == _color;
              return GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getColorFromHex(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.onSurface
                          : Colors.transparent,
                      width: isSelected ? 3 : 0,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_nameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Name ist erforderlich')),
              );
              return;
            }
            final provider = context.read<PlannerProvider>();
            final navigator = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);
            try {
              if (widget.type == null) {
                await provider.createType(
                    name: _nameController.text.trim(), color: _color);
              } else {
                await provider.updateType(
                  widget.type!.id,
                  name: _nameController.text.trim(),
                  color: _color,
                );
              }
              navigator.pop();
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(content: Text('Fehler: $e')),
              );
            }
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

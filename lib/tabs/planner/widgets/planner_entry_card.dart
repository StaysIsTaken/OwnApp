import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/tabs/planner/widgets/planner_edit_dialog.dart';
import 'package:provider/provider.dart';
import 'package:productivity/provider/planner_provider.dart';

class PlannerEntryCard extends StatelessWidget {
  final PlannerEntry entry;
  final VoidCallback? onDelete;

  const PlannerEntryCard({super.key, required this.entry, this.onDelete});

  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: _getColorFromHex(entry.color), width: 4),
          ),
        ),
        child: ListTile(
          title: Text(entry.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.description != null && entry.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    entry.description!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.scheduledAt.hour.toString().padLeft(2, '0')}:${entry.scheduledAt.minute.toString().padLeft(2, '0')} – ${entry.endsAt.hour.toString().padLeft(2, '0')}:${entry.endsAt.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          trailing: PopupMenuButton(
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                child: const Text('Bearbeiten'),
                onTap: () => _showEditDialog(context),
              ),
              PopupMenuItem(
                child: const Text('Löschen'),
                onTap: () => _showDeleteConfirm(context),
              ),
            ],
          ),
          onTap: () => _showDetailView(context),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => PlannerEditDialog(
        entry: entry,
        onSave:
            (
              title,
              description,
              typeId,
              scheduledAt,
              endsAt,
              notifyMinBefore,
              color,
              parentId,
              orderIndex,
            ) {
              context.read<PlannerProvider>().updateEntry(
                entry.id,
                title: title,
                description: description,
                typeId: typeId,
                scheduledAt: scheduledAt,
                endsAt: endsAt,
                notifyMinBefore: notifyMinBefore,
                color: color,
                parentId: parentId,
                orderIndex: orderIndex,
              );
              Navigator.of(context).pop();
            },
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Löschen bestätigen'),
        content: const Text('Möchtest du diesen Eintrag wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              context.read<PlannerProvider>().deleteEntry(entry.id);
              Navigator.of(context).pop();
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  void _showDetailView(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            if (entry.description != null && entry.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(entry.description!),
              ),
            Row(
              children: [
                Chip(
                  label: Text(entry.type ?? 'Ohne Typ'),
                  backgroundColor: _getColorFromHex(
                    entry.color,
                  ).withOpacity(0.2),
                  labelStyle: TextStyle(color: _getColorFromHex(entry.color)),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    '${entry.scheduledAt.hour.toString().padLeft(2, '0')}:${entry.scheduledAt.minute.toString().padLeft(2, '0')} – ${entry.endsAt.hour.toString().padLeft(2, '0')}:${entry.endsAt.minute.toString().padLeft(2, '0')}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Geplant für: ${entry.scheduledAt.day}.${entry.scheduledAt.month}.${entry.scheduledAt.year} ${entry.scheduledAt.hour.toString().padLeft(2, '0')}:${entry.scheduledAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showEditDialog(context);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Bearbeiten'),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showDeleteConfirm(context);
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Löschen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

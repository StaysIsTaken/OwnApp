import 'package:flutter/material.dart';
import 'package:productivity/main.dart';

// ─────────────────────────────────────────────
//  ManageItemTile
//  Reusable list tile for management pages
//  (Categories, Ingredients, Units).
//  Shows a title + optional subtitle with
//  edit and delete action buttons.
// ─────────────────────────────────────────────
class ManageItemTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ManageItemTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: text.bodySmall),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_outlined, color: colors.primary, size: 20),
              onPressed: onEdit,
              tooltip: 'Bearbeiten',
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.delete_outline, color: colors.error, size: 20),
              onPressed: onDelete,
              tooltip: 'Löschen',
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

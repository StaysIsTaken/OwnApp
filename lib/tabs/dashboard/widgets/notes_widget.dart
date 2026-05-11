import 'package:flutter/material.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/note.dart';
import 'package:productivity/tabs/notes/note_editor_page.dart';

class NotesWidget extends StatelessWidget {
  final List<Note> notes;
  final VoidCallback? onRefresh;

  const NotesWidget({
    super.key,
    required this.notes,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final recentNotes = List<Note>.from(notes)
      ..sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt;
        final bDate = b.updatedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });

    return _DashboardCard(
      onTap: () => Navigator.pushNamed(context, AppRoutes.notes),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note_outlined, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Notizen',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${notes.length}',
                style: text.titleMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: colors.outline),
            ],
          ),
          const SizedBox(height: 12),
          if (notes.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.note_add, color: colors.onSurfaceVariant, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Noch keine Notizen vorhanden',
                      style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            )
          else
            ...recentNotes.take(4).map((note) => _NoteItem(
                  note: note,
                  onRefresh: onRefresh,
                )),
          if (notes.length > 4) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                '+ ${notes.length - 4} weitere Notizen',
                style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteItem extends StatelessWidget {
  final Note note;
  final VoidCallback? onRefresh;

  const _NoteItem({required this.note, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final preview = note.text.length > 80
        ? '${note.text.substring(0, 80)}...'
        : note.text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NoteEditorPage(
                  note: note,
                  onSaved: () => onRefresh?.call(),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title,
                        style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (note.tags.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          note.tags.first,
                          style: text.labelSmall?.copyWith(
                            color: colors.primary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _DashboardCard({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

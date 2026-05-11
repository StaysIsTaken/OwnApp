import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/note.dart';
import 'package:productivity/dataclasses/note_folder.dart';

class FolderTree extends StatefulWidget {
  final List<NoteFolder> folders;
  final List<Note> notes;
  final String? selectedFolderId;
  final Note? selectedNote;
  final Function(String?) onFolderSelected;
  final Function(Note) onNoteSelected;
  final Function(String? parentId) onCreateFolder;
  final Function(String) onDeleteFolder;
  final Function(String, String) onRenameFolder;
  final Function(String, String?) onMoveNote;
  final Function() onRefresh;

  const FolderTree({
    super.key,
    required this.folders,
    required this.notes,
    required this.selectedFolderId,
    required this.selectedNote,
    required this.onFolderSelected,
    required this.onNoteSelected,
    required this.onCreateFolder,
    required this.onDeleteFolder,
    required this.onRenameFolder,
    required this.onMoveNote,
    required this.onRefresh,
  });

  @override
  State<FolderTree> createState() => _FolderTreeState();
}

class _FolderTreeState extends State<FolderTree> {
  late Map<String, bool> _expandedFolders;

  @override
  void initState() {
    super.initState();
    _expandedFolders = {};
    // Root folders sind standardmäßig expandiert
    for (final folder in widget.folders.where((f) => f.parentFolderId == null)) {
      _expandedFolders[folder.id] = true;
    }
  }

  List<NoteFolder> _getSubfolders(String? parentId) {
    return widget.folders.where((f) => f.parentFolderId == parentId).toList();
  }

  List<Note> _getFolderNotes(String? folderId) {
    return widget.notes.where((n) => n.folderId == folderId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Alle Notizen" Button
          Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
              color: widget.selectedFolderId == null
                  ? colors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => widget.onFolderSelected(null),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.note_outlined, size: 18, color: colors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Alle Notizen',
                        style: text.labelSmall?.copyWith(
                          color: widget.selectedFolderId == null ? colors.primary : null,
                          fontWeight: widget.selectedFolderId == null
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Divider(height: 1, color: colors.outline.withValues(alpha: 0.2)),
          // "Neuer Ordner" Button
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: () => _showCreateFolderDialog(context, null),
              icon: const Icon(Icons.create_new_folder, size: 18),
              label: const Text('Neuer Ordner'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 36),
              ),
            ),
          ),
          // Root folders
          ..._buildFolderTree(null, colors, text),
          // Notizen ohne Ordner
          ..._buildRootNotes(colors, text),
        ],
      ),
    );
  }

  List<Widget> _buildFolderTree(String? parentId, ColorScheme colors, TextTheme text) {
    final subfolders = _getSubfolders(parentId);
    final folderNotes = parentId == null ? [] : _getFolderNotes(parentId);

    return [
      // Ordner
      ...subfolders.map((folder) {
        final expanded = _expandedFolders[folder.id] ?? false;
        final hasSubfolders = _getSubfolders(folder.id).isNotEmpty;
        final hasNotes = _getFolderNotes(folder.id).isNotEmpty;

        return Column(
          key: ValueKey(folder.id),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DragTarget<Note>(
              onAcceptWithDetails: (details) {
                widget.onMoveNote(details.data.id, folder.id);
              },
              builder: (context, candidateData, rejectedData) {
                return Material(
                  color: candidateData.isNotEmpty
                      ? colors.primary.withValues(alpha: 0.2)
                      : widget.selectedFolderId == folder.id
                          ? colors.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (hasSubfolders || hasNotes) {
                        setState(() {
                          _expandedFolders[folder.id] = !(expanded);
                        });
                      }
                      widget.onFolderSelected(folder.id);
                    },
                    onSecondaryTap: () => _showFolderContextMenu(context, folder),
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 12 + (parentId == null ? 0 : 16),
                        top: 4,
                        bottom: 4,
                        right: 12,
                      ),
                      child: Row(
                        children: [
                          if (hasSubfolders || hasNotes)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                expanded ? Icons.expand_more : Icons.chevron_right,
                                size: 18,
                                color: colors.onSurfaceVariant,
                              ),
                            )
                          else
                            const SizedBox(width: 22),
                          Icon(
                            Icons.folder,
                            size: 18,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              folder.name,
                              style: text.labelSmall?.copyWith(
                                color: widget.selectedFolderId == folder.id
                                    ? colors.primary
                                    : null,
                                fontWeight: widget.selectedFolderId == folder.id
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            // Unterordner und Notizen wenn expanded
            if (expanded) ...[
              ..._buildFolderTree(folder.id, colors, text),
              ..._buildNotesInFolder(folder.id, colors, text),
            ],
          ],
        );
      }),
    ];
  }

  List<Widget> _buildRootNotes(ColorScheme colors, TextTheme text) {
    final rootNotes = widget.notes.where((n) => n.folderId == null || n.folderId!.isEmpty).toList();
    if (rootNotes.isEmpty) return [];

    return [
      Padding(
        padding: const EdgeInsets.only(left: 12, top: 8, bottom: 4),
        child: Text(
          'Unsortiert',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
        ),
      ),
      ...rootNotes.map((note) => _buildDraggableNote(note, 12, colors, text)),
    ];
  }

  List<Widget> _buildNotesInFolder(String folderId, ColorScheme colors, TextTheme text) {
    final folderNotes = _getFolderNotes(folderId);
    return folderNotes.map((note) => _buildDraggableNote(note, 44, colors, text)).toList();
  }

  Widget _buildDraggableNote(Note note, double leftPadding, ColorScheme colors, TextTheme text) {
    return LongPressDraggable<Note>(
      data: note,
      feedback: Material(
        elevation: 5,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.note, size: 16, color: colors.onPrimary),
              const SizedBox(width: 8),
              Text(
                note.title.isEmpty ? 'Ohne Titel' : note.title,
                style: TextStyle(color: colors.onPrimary),
              ),
            ],
          ),
        ),
      ),
      child: Material(
        color: widget.selectedNote?.id == note.id
            ? colors.secondary.withValues(alpha: 0.1)
            : Colors.transparent,
        child: InkWell(
          onTap: () => widget.onNoteSelected(note),
          child: Padding(
            padding: EdgeInsets.only(left: leftPadding, top: 2, bottom: 2, right: 12),
            child: Row(
              children: [
                Icon(
                  Icons.note,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note.title.isEmpty ? 'Ohne Titel' : note.title,
                    style: text.labelSmall?.copyWith(
                      color: widget.selectedNote?.id == note.id
                          ? colors.secondary
                          : null,
                      fontWeight: widget.selectedNote?.id == note.id
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context, String? parentId) {
    // Das Dialog wird jetzt von notes_page.dart gehandelt
    widget.onCreateFolder(parentId);
  }

  void _showFolderContextMenu(BuildContext context, NoteFolder folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(folder.name),
        content: const Text('Was möchtest du tun?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showCreateFolderDialog(context, folder.id);
            },
            child: const Text('Unterordner erstellen'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showRenameFolderDialog(context, folder);
            },
            child: const Text('Umbenennen'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDeleteFolder(folder.id);
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showRenameFolderDialog(BuildContext context, NoteFolder folder) {
    final controller = TextEditingController(text: folder.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ordner umbenennen'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Neuer Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                widget.onRenameFolder(folder.id, controller.text);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}

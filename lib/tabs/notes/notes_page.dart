import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/note.dart';
import 'package:productivity/dataclasses/note_folder.dart';
import 'package:productivity/dataservice/note_service.dart';
import 'package:productivity/dataservice/note_folder_service.dart';
import 'package:productivity/dataservice/login_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/widgets/notes/folder_tree.dart';
import 'note_editor_page.dart';
import 'note_detail_page.dart';

class NotesPage extends BasePage {
  const NotesPage({super.key}) : super(title: 'Notizen');

  @override
  Widget buildBody(BuildContext context) => const _NotesPageContent();

  @override
  Widget buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        final state = context.findAncestorStateOfType<_NotesPageContentState>();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NoteEditorPage(
              folderId: state?._selectedFolderId,
              onSaved: () {
                state?._loadNotes();
              },
            ),
          ),
        );
      },
      icon: const Icon(Icons.add),
      label: const Text('Neue Notiz'),
    );
  }
}

class _NotesPageContent extends StatefulWidget {
  const _NotesPageContent();

  @override
  State<_NotesPageContent> createState() => _NotesPageContentState();
}

class _FolderNameDialog extends StatefulWidget {
  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neuer Ordner'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'Ordnername',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () {
            debugPrint('Abbrechen geklickt');
            Navigator.pop(context);
          },
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            debugPrint('Erstellen geklickt, Text: ${_controller.text}');
            Navigator.pop(context, _controller.text);
          },
          child: const Text('Erstellen'),
        ),
      ],
    );
  }
}

class _NotesPageContentState extends State<_NotesPageContent> {
  List<Note> _notes = [];
  List<NoteFolder> _folders = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String? _selectedFolderId;
  Note? _selectedNote;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notes = await NoteService.loadAll();
      final folders = await NoteFolderService.loadAll();
      setState(() {
        _notes = notes;
        _folders = folders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNotes() async {
    await _loadData();
  }

  List<Note> get _filteredNotes {
    var filtered = _notes;

    // Filter by folder
    if (_selectedFolderId != null) {
      filtered = filtered
          .where((note) => note.folderId == _selectedFolderId)
          .toList();
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (note) =>
                note.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                note.text.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                note.tags.any(
                  (tag) =>
                      tag.toLowerCase().contains(_searchQuery.toLowerCase()),
                ),
          )
          .toList();
    }

    return filtered;
  }

  Future<void> _deleteNote(Note note) async {
    try {
      await NoteService.delete(note.id);
      await _loadNotes();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Notiz gelöscht')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _createFolder(String? parentId) async {
    debugPrint('_createFolder aufgerufen mit parentId: $parentId');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => _FolderNameDialog(),
    );

    if (result != null && result.isNotEmpty) {
      debugPrint('Dialog zurückgekehrt mit Namen: $result');
      try {
        final folder = NoteFolder(
          id: '',
          userId: '',
          name: result,
          parentFolderId: parentId,
          createdAt: DateTime.now(),
        );
        debugPrint('Erstelle Ordner: ${folder.name} mit parentId: $parentId');
        await NoteFolderService.create(folder);
        debugPrint('Ordner erstellt, lade Daten neu...');
        await _loadNotes();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Ordner erstellt')));
        }
      } catch (e) {
        debugPrint('Fehler beim Erstellen des Ordners: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
        }
      }
    }
  }

  Future<void> _deleteFolder(String folderId) async {
    try {
      await NoteFolderService.delete(folderId);
      await _loadNotes();
      if (mounted) {
        setState(() {
          if (_selectedFolderId == folderId) {
            _selectedFolderId = null;
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ordner gelöscht')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _renameFolder(String folderId, String newName) async {
    try {
      final folder = _folders.firstWhere((f) => f.id == folderId);
      final updated = folder.copyWith(name: newName);
      await NoteFolderService.update(updated);
      await _loadNotes();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ordner umbenannt')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  void _showMoveNoteDialog(Note note) {
    final currentFolderName = note.folderId != null
        ? _folders.where((f) => f.id == note.folderId).firstOrNull?.name
        : null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notiz verschieben'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (note.folderId != null)
                ListTile(
                  leading: const Icon(Icons.clear_all),
                  title: const Text('Kein Ordner'),
                  subtitle: currentFolderName != null
                      ? Text('Aktuell in: $currentFolderName')
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _moveNoteToRoot(note.id);
                  },
                ),
              ..._folders.where((f) => f.id != note.folderId).map((folder) {
                final parent = folder.parentFolderId != null
                    ? _folders
                          .where((f) => f.id == folder.parentFolderId)
                          .firstOrNull
                    : null;
                return ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(folder.name),
                  subtitle: parent != null ? Text('in ${parent.name}') : null,
                  onTap: () {
                    Navigator.pop(context);
                    _moveNote(note.id, folder.id);
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  Future<void> _moveNoteToRoot(String noteId) async {
    try {
      final note = _notes.firstWhere((n) => n.id == noteId);
      final updated = Note(
        id: note.id,
        userId: note.userId,
        title: note.title,
        text: note.text,
        folderId: null,
        tags: note.tags,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        isDeleted: note.isDeleted,
      );
      await NoteService.update(updated);
      await _loadNotes();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Notiz verschoben')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _moveNote(String noteId, String folderId) async {
    try {
      final note = _notes.firstWhere((n) => n.id == noteId);
      final updated = note.copyWith(folderId: folderId);
      await NoteService.update(updated);
      await _loadNotes();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Notiz verschoben')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    if (isMobile) {
      return _buildMobileLayout();
    } else {
      return _buildDesktopLayout();
    }
  }

  Widget _buildMobileLayout() {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final rootFolders = _folders
        .where((f) => f.parentFolderId == null)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SearchAnchor(
            builder: (BuildContext context, SearchController controller) {
              return SearchBar(
                controller: controller,
                padding: const WidgetStatePropertyAll<EdgeInsets>(
                  EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                leading: const Icon(Icons.search),
                hintText: 'Notizen durchsuchen...',
              );
            },
            suggestionsBuilder:
                (BuildContext context, SearchController controller) {
                  return _filteredNotes
                      .map(
                        (note) => ListTile(
                          title: Text(note.title),
                          onTap: () {
                            controller.closeView(note.title);
                          },
                        ),
                      )
                      .toList();
                },
          ),
        ),
        // Ordner-Chips
        if (_folders.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: _selectedFolderId == null,
                    label: const Text('Alle'),
                    onSelected: (_) {
                      setState(() => _selectedFolderId = null);
                    },
                  ),
                ),
                ...rootFolders.map((folder) {
                  final hasSubfolders = _folders.any(
                    (f) => f.parentFolderId == folder.id,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: _selectedFolderId == folder.id,
                      avatar: Icon(
                        hasSubfolders ? Icons.folder_open : Icons.folder,
                        size: 18,
                      ),
                      label: Text(folder.name),
                      onSelected: (_) {
                        setState(() => _selectedFolderId = folder.id);
                      },
                      onDeleted: null,
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.create_new_folder, size: 18),
                    label: const Text('Neu'),
                    onPressed: () => _createFolder(null),
                  ),
                ),
              ],
            ),
          ),
        // Unterordner-Chips wenn ein Ordner mit Unterordnern ausgewählt ist
        if (_selectedFolderId != null &&
            _folders.any((f) => f.parentFolderId == _selectedFolderId))
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _folders
                  .where((f) => f.parentFolderId == _selectedFolderId)
                  .map(
                    (subfolder) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: false,
                        avatar: const Icon(
                          Icons.subdirectory_arrow_right,
                          size: 16,
                        ),
                        label: Text(subfolder.name),
                        onSelected: (_) {
                          setState(() => _selectedFolderId = subfolder.id);
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        Expanded(child: _buildNotesList(colors, text)),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        // Left: Folder Tree
        Container(
          width: 250,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: colors.outline.withValues(alpha: 0.2)),
            ),
          ),
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: colors.primary))
              : FolderTree(
                  folders: _folders,
                  notes: _notes,
                  selectedFolderId: _selectedFolderId,
                  selectedNote: _selectedNote,
                  onFolderSelected: (folderId) {
                    setState(() {
                      _selectedFolderId = folderId;
                      _selectedNote = null;
                    });
                  },
                  onNoteSelected: (note) {
                    setState(() {
                      _selectedNote = note;
                    });
                    // Öffne Editor direkt
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            NoteEditorPage(note: note, onSaved: _loadNotes),
                      ),
                    );
                  },
                  onCreateFolder: (parentId) => _createFolder(parentId),
                  onDeleteFolder: (folderId) => _deleteFolder(folderId),
                  onRenameFolder: (folderId, newName) =>
                      _renameFolder(folderId, newName),
                  onMoveNote: (noteId, folderId) =>
                      _moveNote(noteId, folderId!),
                  onRefresh: _loadNotes,
                ),
        ),
        // Right: Notes List or Editor
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SearchAnchor(
                  builder: (BuildContext context, SearchController controller) {
                    return SearchBar(
                      controller: controller,
                      padding: const WidgetStatePropertyAll<EdgeInsets>(
                        EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                      leading: const Icon(Icons.search),
                      hintText: 'Notizen durchsuchen...',
                    );
                  },
                  suggestionsBuilder:
                      (BuildContext context, SearchController controller) {
                        return _filteredNotes
                            .map(
                              (note) => ListTile(
                                title: Text(note.title),
                                onTap: () {
                                  controller.closeView(note.title);
                                },
                              ),
                            )
                            .toList();
                      },
                ),
              ),
              Expanded(child: _buildNotesList(colors, text)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotesList(ColorScheme colors, TextTheme text) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.error),
            const SizedBox(height: 16),
            Text(
              'Fehler beim Laden der Notizen',
              style: text.bodyMedium?.copyWith(color: colors.error),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadNotes,
              icon: const Icon(Icons.refresh),
              label: const Text('Erneut versuchen'),
            ),
          ],
        ),
      );
    }

    if (_notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_outlined, size: 64, color: colors.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Keine Notizen vorhanden',
              style: text.titleMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'Erstelle deine erste Notiz!',
              style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotes,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _filteredNotes.length,
        itemBuilder: (context, index) {
          final note = _filteredNotes[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: colors.surfaceContainerHighest,
            child: ListTile(
              title: Text(
                note.title,
                style: text.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    note.text.length > 100
                        ? '${note.text.substring(0, 100)}...'
                        : note.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (note.tags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: note.tags
                          .take(3)
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              visualDensity: VisualDensity.compact,
                              labelStyle: text.labelSmall,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Text('Lesen'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NoteDetailPage(note: note),
                        ),
                      );
                    },
                  ),
                  PopupMenuItem(
                    child: const Text('Bearbeiten'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              NoteEditorPage(note: note, onSaved: _loadNotes),
                        ),
                      );
                    },
                  ),
                  if (_folders.isNotEmpty)
                    PopupMenuItem(
                      child: const Text('Verschieben'),
                      onTap: () => _showMoveNoteDialog(note),
                    ),
                  PopupMenuItem(
                    child: const Text('Löschen'),
                    onTap: () => _deleteNote(note),
                  ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        NoteEditorPage(note: note, onSaved: _loadNotes),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

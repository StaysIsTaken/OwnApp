import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/note.dart';
import 'package:productivity/dataservice/note_service.dart';
import 'package:productivity/main.dart';
import 'note_editor_page.dart';

class NotesPage extends BasePage {
  const NotesPage({super.key}) : super(title: 'Notizen');

  @override
  Widget buildBody(BuildContext context) => const _NotesPageContent();
}

class _NotesPageContent extends StatefulWidget {
  const _NotesPageContent();

  @override
  State<_NotesPageContent> createState() => _NotesPageContentState();
}

class _NotesPageContentState extends State<_NotesPageContent> {
  List<Note> _notes = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notes = await NoteService.loadAll();
      setState(() {
        _notes = notes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Note> get _filteredNotes {
    if (_searchQuery.isEmpty) {
      return _notes;
    }
    return _notes
        .where((note) =>
            note.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            note.text.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            note.tags.any((tag) =>
                tag.toLowerCase().contains(_searchQuery.toLowerCase())))
        .toList();
  }

  Future<void> _deleteNote(Note note) async {
    try {
      await NoteService.delete(note.id);
      await _loadNotes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notiz gelöscht')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SearchAnchor(
            builder: (BuildContext context, SearchController controller) {
              return SearchBar(
                controller: controller,
                padding: const MaterialStatePropertyAll<EdgeInsets>(
                    EdgeInsets.symmetric(horizontal: 16)),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                leading: const Icon(Icons.search),
                hintText: 'Notizen durchsuchen...',
              );
            },
            suggestionsBuilder: (BuildContext context, SearchController controller) {
              return _filteredNotes
                  .map((note) => ListTile(
                        title: Text(note.title),
                        onTap: () {
                          controller.closeView(note.title);
                        },
                      ))
                  .toList();
            },
          ),
        ),
        Expanded(
          child: _buildNotesList(colors, text),
        ),
      ],
    );
  }

  Widget _buildNotesList(ColorScheme colors, TextTheme text) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: colors.primary),
      );
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
            Icon(
              Icons.note_outlined,
              size: 64,
              color: colors.onSurfaceVariant,
            ),
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
                    style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
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

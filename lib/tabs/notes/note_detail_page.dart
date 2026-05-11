import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:productivity/dataclasses/note.dart';

class NoteDetailPage extends StatelessWidget {
  final Note note;

  const NoteDetailPage({
    super.key,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(note.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tags
            if (note.tags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                children: note.tags
                    .map(
                      (tag) => Chip(
                        label: Text(tag),
                        backgroundColor: colors.primaryContainer,
                        labelStyle: TextStyle(color: colors.onPrimaryContainer),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Markdown content
            MarkdownBody(
              data: note.text,
              selectable: true,
              onTapLink: (text, href, title) {
                // Handle [[...]] style backlinks
                if (href != null && href.startsWith('[[') && href.endsWith(']]')) {
                  final backlinkedTitle = href.substring(2, href.length - 2);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Backlink to "$backlinkedTitle" (not yet navigable)'),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/note.dart';
import 'package:productivity/dataservice/note_service.dart';
import 'package:productivity/dataservice/ai_service.dart';
import 'package:productivity/provider/settings_provider.dart';
import 'package:productivity/widgets/notes/markdown_editor.dart';
import 'package:provider/provider.dart';
import 'package:productivity/dataservice/login_service.dart';

class NoteEditorPage extends StatefulWidget {
  final Note? note;
  final VoidCallback onSaved;

  const NoteEditorPage({
    super.key,
    this.note,
    required this.onSaved,
  });

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _tagsController;
  late TextEditingController _textController;

  String _generatedText = '';
  bool _isGenerating = false;
  String? _generationError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _tagsController = TextEditingController(
      text: widget.note != null ? widget.note!.formatTags() : '',
    );
    _textController = TextEditingController(text: widget.note?.text ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagsController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Titel erforderlich')),
      );
      return;
    }

    try {
      final user = await LoginService.currentUser;

      if (widget.note != null) {
        final updated = widget.note!.copyWith(
          title: _titleController.text,
          text: _textController.text,
          tags: Note.parseTags(_tagsController.text),
        );
        await NoteService.update(updated);
      } else {
        final newNote = Note(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: user.id,
          title: _titleController.text,
          text: _textController.text,
          tags: Note.parseTags(_tagsController.text),
          createdAt: DateTime.now(),
        );
        await NoteService.create(newNote);
      }

      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notiz gespeichert')),
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

  Future<void> _generateText(String prompt) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    setState(() {
      _isGenerating = true;
      _generationError = null;
      _generatedText = '';
    });

    try {
      final result = await AIService.generateTextComplete(
        model: settings.selectedAIModel,
        prompt: prompt,
        temperature: settings.aiTemperature,
        maxTokens: settings.aiMaxTokens,
      );

      if (mounted) {
        setState(() {
          _generatedText = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _generationError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  void _insertGeneratedText() {
    if (_generatedText.isNotEmpty) {
      final current = _textController.text;
      final newText = current.isEmpty ? _generatedText : '$current\n\n$_generatedText';
      _textController.text = newText;
      setState(() {
        _generatedText = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note != null ? 'Notiz bearbeiten' : 'Neue Notiz'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveNote,
            tooltip: 'Speichern',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Titel',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: colors.surface,
                ),
                style: text.headlineSmall,
              ),
              const SizedBox(height: 16),

              // Tags
              TextField(
                controller: _tagsController,
                decoration: InputDecoration(
                  labelText: 'Tags (kommagetrennt)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: colors.surface,
                  hintText: 'Tag1, Tag2, Tag3',
                ),
              ),
              const SizedBox(height: 16),

              // Editor with toolbar
              Container(
                height: 400,
                decoration: BoxDecoration(
                  border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: MarkdownEditor(
                  initialText: widget.note?.text ?? '',
                  onChanged: (text) => _textController.text = text,
                  controller: _textController,
                ),
              ),
              const SizedBox(height: 16),

              // AI Generation Panel
              if (!isMobile)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KI-Assistent',
                        style: text.titleSmall?.copyWith(color: colors.primary),
                      ),
                      const SizedBox(height: 12),
                      _buildAIPanel(colors, text),
                    ],
                  ),
                )
              else
                ExpansionTile(
                  title: Text(
                    'KI-Assistent',
                    style: text.titleSmall?.copyWith(color: colors.primary),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: _buildAIPanel(colors, text),
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              // TODO: Backlinks werden später implementiert
              // Die API gibt Links zurück, die wir zu vollständigen Notizen auflösen müssten
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIPanel(ColorScheme colors, TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Generate button
        ElevatedButton.icon(
          onPressed: _isGenerating
              ? null
              : () {
                  final prompt =
                      'Schreibe einen Text über: ${_titleController.text}';
                  _generateText(prompt);
                },
          icon: _isGenerating ? null : const Icon(Icons.auto_awesome),
          label: Text(_isGenerating ? 'Generiere...' : 'Text generieren'),
        ),
        if (_isGenerating) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(color: colors.primary),
        ],
        if (_generationError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _generationError!,
              style: text.bodySmall?.copyWith(color: colors.onErrorContainer),
            ),
          ),
        ],
        if (_generatedText.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generierter Text:',
                  style: text.labelSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _generatedText,
                  style: text.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _insertGeneratedText,
                      icon: const Icon(Icons.check),
                      label: const Text('Einfügen'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _generatedText = '');
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Ablehnen'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

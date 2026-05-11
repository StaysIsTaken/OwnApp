import 'package:flutter/material.dart';

class MarkdownEditor extends StatefulWidget {
  final String initialText;
  final Function(String) onChanged;
  final int maxLines;
  final bool showToolbar;

  const MarkdownEditor({
    super.key,
    this.initialText = '',
    required this.onChanged,
    this.maxLines = 0,
    this.showToolbar = true,
  });

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _controller.addListener(() {
      widget.onChanged(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _insertMarkdown(String before, {String after = ''}) {
    final selection = _controller.selection;
    final text = _controller.text;
    final selectedText = text.substring(selection.start, selection.end);

    final newText = text.replaceRange(
      selection.start,
      selection.end,
      '$before$selectedText$after',
    );

    _controller.text = newText;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: selection.start + before.length + selectedText.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (widget.showToolbar) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // Bold
                  _ToolbarButton(
                    icon: Icons.format_bold,
                    tooltip: 'Fett',
                    onPressed: () => _insertMarkdown('**', after: '**'),
                  ),
                  const SizedBox(width: 8),

                  // Italic
                  _ToolbarButton(
                    icon: Icons.format_italic,
                    tooltip: 'Kursiv',
                    onPressed: () => _insertMarkdown('*', after: '*'),
                  ),
                  const SizedBox(width: 8),

                  // Code
                  _ToolbarButton(
                    icon: Icons.code,
                    tooltip: 'Code',
                    onPressed: () => _insertMarkdown('`', after: '`'),
                  ),
                  const SizedBox(width: 8),

                  // Link
                  _ToolbarButton(
                    icon: Icons.link,
                    tooltip: 'Link/Backlink',
                    onPressed: () => _insertMarkdown('[[', after: ']]'),
                  ),
                  const SizedBox(width: 8),

                  // Heading
                  _ToolbarButton(
                    icon: Icons.title,
                    tooltip: 'Überschrift',
                    onPressed: () {
                      final selection = _controller.selection;
                      if (selection.start == 0 ||
                          _controller.text[selection.start - 1] == '\n') {
                        _insertMarkdown('# ');
                      } else {
                        _insertMarkdown('\n# ');
                      }
                    },
                  ),
                  const SizedBox(width: 8),

                  // Quote
                  _ToolbarButton(
                    icon: Icons.format_quote,
                    tooltip: 'Zitat',
                    onPressed: () {
                      final selection = _controller.selection;
                      if (selection.start == 0 ||
                          _controller.text[selection.start - 1] == '\n') {
                        _insertMarkdown('> ');
                      } else {
                        _insertMarkdown('\n> ');
                      }
                    },
                  ),
                  const SizedBox(width: 8),

                  // List
                  _ToolbarButton(
                    icon: Icons.format_list_bulleted,
                    tooltip: 'Liste',
                    onPressed: () {
                      final selection = _controller.selection;
                      if (selection.start == 0 ||
                          _controller.text[selection.start - 1] == '\n') {
                        _insertMarkdown('- ');
                      } else {
                        _insertMarkdown('\n- ');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: colors.outline.withValues(alpha: 0.2)),
        ],
        Expanded(
          child: TextField(
            controller: _controller,
            maxLines: widget.maxLines,
            expands: widget.maxLines == null,
            decoration: InputDecoration(
              hintText: 'Notiz schreiben...',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
        splashRadius: 20,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataservice/ai_service.dart';
import 'package:productivity/dataservice/assistant_service.dart';
import 'package:productivity/provider/settings_provider.dart';
import 'package:productivity/provider/planner_provider.dart';
import 'package:productivity/widgets/mic_button.dart';

class _PendingItem {
  final AssistantPendingAction action;
  String status = 'open'; // 'open' | 'done' | 'dismissed'
  _PendingItem(this.action);
}

class _ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final List<_PendingItem> pending;
  _ChatMessage(this.role, this.content, {this.pending = const []});
}

class AssistantPage extends BasePage {
  const AssistantPage({super.key}) : super(title: 'Assistent');

  @override
  Widget buildBody(BuildContext context) => const AssistantChatView();
}

/// Wiederverwendbare Chat-Ansicht (Seite UND globales Overlay nutzen sie).
class AssistantChatView extends StatefulWidget {
  const AssistantChatView({super.key});

  @override
  State<AssistantChatView> createState() => _AssistantChatViewState();
}

class _AssistantChatViewState extends State<AssistantChatView> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;

    final settings = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _messages.add(_ChatMessage('user', text));
      _input.clear();
      _sending = true;
    });
    _scrollToEnd();

    try {
      final model = await AIService.resolveModel(settings.selectedAIModel);
      final history = _messages
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();
      final result =
          await AssistantService.chat(messages: history, model: model);

      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          'assistant',
          result.reply,
          pending: result.pendingActions.map((a) => _PendingItem(a)).toList(),
        ));
      });
      _scrollToEnd();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirm(_PendingItem item) async {
    final provider = context.read<PlannerProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final affects =
          await AssistantService.execute(item.action.kind, item.action.params);
      if (affects == 'planner') {
        provider.loadEntries();
      }
      if (mounted) setState(() => item.status = 'done');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? _emptyState(theme)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) => _bubble(theme, _messages[i]),
                ),
        ),
        if (_sending) const LinearProgressIndicator(minHeight: 2),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Frag mich etwas …',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                MicButton(
                  onText: (text) {
                    final base = _input.text.trim();
                    _input.text = base.isEmpty ? text : '$base $text';
                    _input.selection = TextSelection.fromPosition(
                      TextPosition(offset: _input.text.length),
                    );
                  },
                ),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.smart_toy_outlined, size: 64, color: theme.hintColor),
            const SizedBox(height: 16),
            Text('Dein Assistent', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'z.B. „Was hab ich diese Woche vor?", „Hab ich noch Vorräte?", '
              '„Leg morgen 9 Uhr Zahnarzt an", „Was hab ich über X notiert?"',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(ThemeData theme, _ChatMessage m) {
    final isUser = m.role == 'user';
    final bg = isUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final fg = isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints:
                BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
            decoration:
                BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: isUser
                ? Text(m.content.isEmpty ? '…' : m.content,
                    style: TextStyle(color: fg))
                : MarkdownBody(
                    data: m.content.isEmpty ? '…' : m.content,
                    selectable: true,
                    styleSheet:
                        MarkdownStyleSheet.fromTheme(theme).copyWith(
                      p: TextStyle(color: fg),
                      listBullet: TextStyle(color: fg),
                      strong: TextStyle(
                          color: fg, fontWeight: FontWeight.bold),
                      em: TextStyle(color: fg, fontStyle: FontStyle.italic),
                      code: TextStyle(
                        color: fg,
                        backgroundColor:
                            theme.colorScheme.surface.withValues(alpha: 0.5),
                      ),
                      h1: TextStyle(color: fg, fontWeight: FontWeight.bold),
                      h2: TextStyle(color: fg, fontWeight: FontWeight.bold),
                      h3: TextStyle(color: fg, fontWeight: FontWeight.bold),
                    ),
                  ),
          ),
        ),
        // Bestätigungs-Karten
        ...m.pending.map((item) => _actionCard(theme, item)),
      ],
    );
  }

  IconData _actionIcon(String kind) {
    switch (kind) {
      case 'delete_planner_entry':
        return Icons.delete_outline;
      case 'update_planner_entry':
      case 'update_time_entry':
        return Icons.edit_outlined;
      case 'create_recurring_entry':
        return Icons.repeat;
      case 'create_subtask':
        return Icons.subdirectory_arrow_right;
      case 'create_note':
        return Icons.note_add_outlined;
      case 'create_journal_entry':
        return Icons.book_outlined;
      case 'add_shopping_item':
        return Icons.add_shopping_cart;
      case 'update_shopping_item':
        return Icons.check_circle_outline;
      case 'remove_shopping_item':
        return Icons.remove_shopping_cart_outlined;
      case 'update_pantry_item':
        return Icons.kitchen_outlined;
      case 'create_recipe':
        return Icons.menu_book_outlined;
      case 'create_category':
      case 'create_ingredient':
      case 'create_unit':
      case 'create_storage_location':
      case 'create_planner_type':
        return Icons.label_outline;
      default:
        return Icons.event_available;
    }
  }

  Widget _actionCard(ThemeData theme, _PendingItem item) {
    final isDelete = item.action.kind == 'delete_planner_entry';
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 6),
      padding: const EdgeInsets.all(12),
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_actionIcon(item.action.kind),
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(item.action.label,
                    style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (item.status == 'open')
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => item.status = 'dismissed'),
                  child: const Text('Verwerfen'),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: () => _confirm(item),
                  child: Text(isDelete ? 'Löschen' : 'Bestätigen'),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(
                  item.status == 'done' ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: item.status == 'done'
                      ? Colors.green
                      : theme.hintColor,
                ),
                const SizedBox(width: 4),
                Text(
                  item.status == 'done' ? 'Erledigt' : 'Verworfen',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

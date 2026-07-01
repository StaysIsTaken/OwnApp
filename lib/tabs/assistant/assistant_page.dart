import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:productivity/main.dart';
import 'package:productivity/provider/settings_provider.dart';
import 'package:productivity/provider/planner_provider.dart';
import 'package:productivity/provider/chat_provider.dart';
import 'package:productivity/widgets/mic_button.dart';

class AssistantPage extends BasePage {
  const AssistantPage({super.key}) : super(title: 'Assistent');

  @override
  Widget buildBody(BuildContext context) => const AssistantChatView();
}

/// Wiederverwendbare Chat-Ansicht (Seite UND globales Overlay nutzen sie).
/// Der Zustand liegt im app-weiten [ChatProvider] – so bleibt eine Antwort
/// erhalten, auch wenn man das Fenster verlässt.
class AssistantChatView extends StatefulWidget {
  const AssistantChatView({super.key});

  @override
  State<AssistantChatView> createState() => _AssistantChatViewState();
}

class _AssistantChatViewState extends State<AssistantChatView> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Chat-Fenster ist sichtbar -> keine Notification bei Antworten.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ChatProvider>().setActive(true);
    });
  }

  @override
  void dispose() {
    // Fenster verlassen -> künftige Antworten lösen eine Notification aus.
    try {
      context.read<ChatProvider>().setActive(false);
    } catch (_) {}
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
    final chat = context.read<ChatProvider>();
    if (text.isEmpty || chat.sending) return;

    final settings = context.read<SettingsProvider>();
    final model = settings.selectedAIModel.isEmpty
        ? null
        : settings.selectedAIModel;

    _input.clear();
    _scrollToEnd();
    await chat.send(text, model: model);
    _scrollToEnd();
  }

  Future<void> _confirm(ChatPendingItem item) async {
    final chat = context.read<ChatProvider>();
    final provider = context.read<PlannerProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final affects = await chat.confirm(item);
      if (affects == 'planner') {
        provider.loadEntries();
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chat = context.watch<ChatProvider>();
    final messages = chat.messages;

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? _emptyState(theme)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) => _bubble(theme, messages[i]),
                ),
        ),
        if (chat.sending) const LinearProgressIndicator(minHeight: 2),
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
                  onPressed: chat.sending ? null : _send,
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

  Widget _bubble(ThemeData theme, ChatMessage m) {
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
                    // selectable:true crasht auf Desktop (flutter_markdown-Bug
                    // in onSelectionChanged) -> aus.
                    selectable: false,
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

  Widget _actionCard(ThemeData theme, ChatPendingItem item) {
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
                  onPressed: () =>
                      context.read<ChatProvider>().dismiss(item),
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

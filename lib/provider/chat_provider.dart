import 'package:flutter/widgets.dart';
import 'package:productivity/dataservice/assistant_service.dart';
import 'package:productivity/dataservice/local_notification_manager.dart';

/// Ein vom Assistenten vorgeschlagener, zu bestätigender Vorgang.
class ChatPendingItem {
  final AssistantPendingAction action;
  String status; // 'open' | 'done' | 'dismissed'
  ChatPendingItem(this.action, {this.status = 'open'});
}

class ChatMessage {
  final String role; // 'user' | 'assistant'
  String content; // veränderbar für Live-Streaming der Antwort
  final List<ChatPendingItem> pending;
  ChatMessage(this.role, this.content, {List<ChatPendingItem>? pending})
      : pending = pending ?? [];
}

/// Hält den Chat-Zustand APP-WEIT (nicht im Widget), damit eine Antwort auch
/// dann ankommt und erhalten bleibt, wenn man das Chat-Fenster verlässt.
/// Ist das Fenster geschlossen oder die App im Hintergrund, wird bei einer
/// Antwort eine lokale Notification ausgelöst.
class ChatProvider extends ChangeNotifier with WidgetsBindingObserver {
  final List<ChatMessage> messages = [];
  bool _sending = false;
  bool _active = false; // Chat-Ansicht sichtbar?
  bool _foreground = true; // App im Vordergrund?

  bool get sending => _sending;

  ChatProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  /// Vom Chat-Fenster gesetzt (initState -> true, dispose -> false).
  void setActive(bool value) => _active = value;

  Future<void> send(String text, {String? model}) async {
    final t = text.trim();
    if (t.isEmpty || _sending) return;

    messages.add(ChatMessage('user', t));
    // Verlauf VOR dem Platzhalter einsammeln (ohne die leere Assistenten-Bubble).
    final history =
        messages.map((m) => {'role': m.role, 'content': m.content}).toList();
    final assistant = ChatMessage('assistant', '');
    messages.add(assistant);
    _sending = true;
    notifyListeners();

    try {
      final result = await AssistantService.chat(
        messages: history,
        model: model,
        onToken: (delta) {
          assistant.content += delta; // wächst live in der Bubble
          notifyListeners();
        },
      );
      // Kanonischen Text setzen (räumt evtl. Zwischen-Token auf) + Karten anhängen.
      assistant.content = result.reply;
      assistant.pending
        ..clear()
        ..addAll(result.pendingActions.map((a) => ChatPendingItem(a)));
      _maybeNotify(result.reply);
    } catch (e) {
      assistant.content = 'Fehler: $e';
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  void _maybeNotify(String reply) {
    // Nur benachrichtigen, wenn der Nutzer NICHT gerade zuschaut.
    if (_active && _foreground) return;
    final body = reply.trim().isEmpty
        ? 'Neue Antwort vom Assistenten.'
        : (reply.length > 80 ? '${reply.substring(0, 77)}…' : reply);
    LocalNotificationManager().showNotification(
      id: 920001,
      title: 'Assistent',
      body: body,
      channelId: LocalNotificationManager.channelChat,
    );
  }

  /// Führt eine bestätigte Aktion aus; liefert 'affects' (z.B. 'planner').
  Future<String?> confirm(ChatPendingItem item) async {
    final affects =
        await AssistantService.execute(item.action.kind, item.action.params);
    item.status = 'done';
    notifyListeners();
    return affects;
  }

  void dismiss(ChatPendingItem item) {
    item.status = 'dismissed';
    notifyListeners();
  }

  void clear() {
    messages.clear();
    _sending = false;
    notifyListeners();
  }
}

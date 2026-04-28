import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/chat.dart';
import 'package:productivity/dataclasses/User.dart';
import 'package:productivity/dataservice/chat_service.dart';
import 'package:productivity/dataservice/user_service.dart';
import 'package:productivity/dataservice/login_service.dart';
import 'package:productivity/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class ChatPage extends BasePage {
  const ChatPage({super.key}) : super(title: 'Chat');

  @override
  Widget buildBody(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          return const _DesktopChatLayout();
        } else {
          return const _ChatListContent();
        }
      },
    );
  }
}

class _DesktopChatLayout extends StatefulWidget {
  const _DesktopChatLayout();

  @override
  State<_DesktopChatLayout> createState() => _DesktopChatLayoutState();
}

class _DesktopChatLayoutState extends State<_DesktopChatLayout> {
  ChatRoom? _selectedRoom;
  final GlobalKey<_ChatListContentState> _listKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 350,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: colors.outlineVariant.withOpacity(0.5))),
            ),
            child: _ChatListContent(
              key: _listKey,
              onRoomSelected: (room) => setState(() => _selectedRoom = room),
              selectedRoomId: _selectedRoom?.id,
            ),
          ),
        ),
        Expanded(
          child: _selectedRoom == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: colors.outline.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      const Text('Wähle einen Chat aus, um zu schreiben'),
                    ],
                  ),
                )
              : KeyedSubtree(
                  key: ValueKey(_selectedRoom!.id),
                  child: _ChatRoomView(
                    room: _selectedRoom!,
                    onDeleted: () {
                      setState(() => _selectedRoom = null);
                      _listKey.currentState?._load();
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _ChatListContent extends StatefulWidget {
  final Function(ChatRoom)? onRoomSelected;
  final String? selectedRoomId;

  const _ChatListContent({super.key, this.onRoomSelected, this.selectedRoomId});

  @override
  State<_ChatListContent> createState() => _ChatListContentState();
}

class _ChatListContentState extends State<_ChatListContent> {
  List<ChatRoom> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rooms = await ChatService.getRooms();
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCreateDialog() async {
    final users = await UserService.getAllUsers();
    if (!mounted) return;
    
    final me = Provider.of<UserProvider>(context, listen: false).user;
    final otherUsers = users.where((u) => u.id != me?.id).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (context) => _CreateChatForm(
        users: otherUsers,
        onCreated: (room) {
          _load();
          if (widget.onRoomSelected != null) widget.onRoomSelected!(room);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add_comment_outlined),
      ),
      body: _rooms.isEmpty
          ? const Center(child: Text('Noch keine Chats vorhanden.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _rooms.length,
                itemBuilder: (context, i) {
                  final room = _rooms[i];
                  final isSelected = room.id == widget.selectedRoomId;
                  final colors = Theme.of(context).colorScheme;

                  String subtitle = 'Noch keine Nachrichten';
                  if (room.lastMessage != null) {
                    if (room.isGroup) {
                      subtitle = '${room.lastMessage!.senderName}: ${room.lastMessage!.message}';
                    } else {
                      subtitle = room.lastMessage!.message;
                    }
                  }

                  String timeStr = '';
                  if (room.lastMessage != null) {
                    final now = DateTime.now();
                    final date = room.lastMessage!.createdAt;
                    if (now.day == date.day && now.month == date.month && now.year == date.year) {
                      timeStr = DateFormat('HH:mm').format(date);
                    } else {
                      timeStr = DateFormat('dd.MM.').format(date);
                    }
                  }

                  return ListTile(
                    selected: isSelected,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: room.isGroup ? colors.primaryContainer : colors.secondaryContainer,
                      child: Text(
                        room.displayName.isNotEmpty ? room.displayName[0].toUpperCase() : '?',
                        style: TextStyle(color: room.isGroup ? colors.onPrimaryContainer : colors.onSecondaryContainer, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            room.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (timeStr.isNotEmpty)
                          Text(timeStr, style: TextStyle(fontSize: 12, color: colors.outline)),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.outline, fontSize: 14),
                      ),
                    ),
                    onTap: () {
                      if (widget.onRoomSelected != null) {
                        widget.onRoomSelected!(room);
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => _MobileChatRoomPage(
                          room: room,
                          onDeleted: _load,
                        )));
                      }
                    },
                  );
                },
              ),
            ),
    );
  }
}

class _CreateChatForm extends StatefulWidget {
  final List<User> users;
  final Function(ChatRoom) onCreated;

  const _CreateChatForm({required this.users, required this.onCreated});

  @override
  State<_CreateChatForm> createState() => _CreateChatFormState();
}

class _CreateChatFormState extends State<_CreateChatForm> {
  final _nameCtrl = TextEditingController();
  final Set<String> _selectedUserIds = {};
  bool _isGroup = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_isGroup ? 'Neue Gruppe' : 'Neuer Chat', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Gruppen-Chat'),
            value: _isGroup,
            onChanged: (v) => setState(() => _isGroup = v),
          ),
          if (_isGroup)
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Gruppenname'),
            ),
          const SizedBox(height: 16),
          const Text('Teilnehmer auswählen:', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: widget.users.length,
              itemBuilder: (context, i) {
                final user = widget.users[i];
                return CheckboxListTile(
                  title: Text('${user.firstname} ${user.lastname}'),
                  subtitle: Text(user.username),
                  value: _selectedUserIds.contains(user.id),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) _selectedUserIds.add(user.id);
                      else _selectedUserIds.remove(user.id);
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
              ElevatedButton(
                onPressed: _selectedUserIds.isEmpty ? null : () async {
                  final room = await ChatService.createRoom(
                    _nameCtrl.text.isEmpty ? 'Gruppe' : _nameCtrl.text,
                    _isGroup,
                    _selectedUserIds.toList(),
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  widget.onCreated(room);
                },
                child: const Text('Erstellen'),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ChatRoomView extends StatefulWidget {
  final ChatRoom room;
  final VoidCallback? onDeleted;
  const _ChatRoomView({required this.room, this.onDeleted});

  @override
  State<_ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<_ChatRoomView> {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    try {
      final history = await ChatService.getMessages(widget.room.id);
      if (mounted) {
        setState(() {
          _messages.addAll(history);
          _messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _loadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingHistory = false);
    }

    final token = await LoginService.getToken();
    if (token != null && mounted) {
      _channel = ChatService.connect(widget.room.id, token);
      _subscription = _channel?.stream.listen((event) {
        _handleNewMessage(event);
      });
    }
  }

  void _handleNewMessage(dynamic event) {
    try {
      final data = jsonDecode(event.toString());
      final newMsg = ChatMessage.fromJson(data);
      if (mounted) {
        setState(() {
          if (!_messages.any((m) => m.id == newMsg.id)) {
            _messages.insert(0, newMsg);
          }
        });
      }
    } catch (e) {}
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _channel?.sink.add(text);
    _controller.clear();
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (context) => _ChatSettingsView(
        room: widget.room,
        onDeleted: () {
          if (widget.onDeleted != null) widget.onDeleted!();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final userProvider = Provider.of<UserProvider>(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(bottom: BorderSide(color: colors.outlineVariant.withOpacity(0.3))),
          ),
          child: Row(
            children: [
              Text(widget.room.displayName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.info_outline, size: 20), onPressed: _showSettings),
            ],
          ),
        ),
        Expanded(
          child: _loadingHistory && _messages.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    final msg = _messages[i];
                    final isMe = msg.senderId == userProvider.user?.id;
                    return _ChatBubble(
                      message: msg.message,
                      isMe: isMe,
                      senderName: msg.senderName,
                      time: DateFormat('HH:mm').format(msg.createdAt),
                      showSenderName: widget.room.isGroup && !isMe,
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.outlineVariant.withOpacity(0.3))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Nachricht schreiben...',
                    filled: true,
                    fillColor: colors.surfaceVariant.withOpacity(0.3),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: colors.primary,
                child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sendMessage),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatSettingsView extends StatefulWidget {
  final ChatRoom room;
  final VoidCallback? onDeleted;
  const _ChatSettingsView({required this.room, this.onDeleted});

  @override
  State<_ChatSettingsView> createState() => _ChatSettingsViewState();
}

class _ChatSettingsViewState extends State<_ChatSettingsView> {
  List<User> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final members = await ChatService.getMembers(widget.room.id);
      if (mounted) setState(() { _members = members; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Chat-Einstellungen', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          if (widget.room.isGroup) ...[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Name ändern'),
              onTap: () async { /* TODO */ },
            ),
            ListTile(
              leading: const Icon(Icons.person_add_outlined),
              title: const Text('Mitglied hinzufügen'),
              onTap: () async { /* TODO */ },
            ),
            const Divider(),
          ],
          const Text('Teilnehmer:', style: TextStyle(fontWeight: FontWeight.bold)),
          if (_loading) const CircularProgressIndicator()
          else Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _members.length,
              itemBuilder: (context, i) {
                final member = _members[i];
                final isMe = member.id == userProvider.user?.id;
                return ListTile(
                  leading: CircleAvatar(child: Text(member.firstname.isNotEmpty ? member.firstname[0] : '?')),
                  title: Text('${member.firstname} ${member.lastname}'),
                  subtitle: Text(member.username),
                  trailing: (widget.room.isGroup && !isMe)
                      ? IconButton(
                          icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
                          onPressed: () async {
                            await ChatService.removeMember(widget.room.id, member.id);
                            _load();
                          },
                        )
                      : null,
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              await ChatService.deleteRoom(widget.room.id);
              if (!mounted) return;
              Navigator.pop(context);
              if (widget.onDeleted != null) widget.onDeleted!();
            },
            icon: const Icon(Icons.exit_to_app),
            label: Text(widget.room.isGroup ? 'Gruppe verlassen' : 'Chat löschen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.errorContainer,
              foregroundColor: colors.onErrorContainer,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String? senderName;
  final String time;
  final bool showSenderName;

  const _ChatBubble({
    required this.message,
    required this.isMe,
    this.senderName,
    required this.time,
    this.showSenderName = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSenderName && senderName != null)
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 4.0, right: 8.0),
              child: Text(
                senderName!,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.primary),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            decoration: BoxDecoration(
              color: isMe ? colors.primary : colors.secondaryContainer,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  message,
                  style: TextStyle(color: isMe ? colors.onPrimary : colors.onSecondaryContainer),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 10,
                    color: (isMe ? colors.onPrimary : colors.onSecondaryContainer).withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MobileChatRoomPage extends StatelessWidget {
  final ChatRoom room;
  final VoidCallback? onDeleted;
  const _MobileChatRoomPage({required this.room, this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(room.displayName)),
      body: _ChatRoomView(
        room: room,
        onDeleted: () {
          Navigator.pop(context);
          if (onDeleted != null) onDeleted!();
        },
      ),
    );
  }
}

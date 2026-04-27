import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:productivity/dataservice/api_client.dart';
import 'package:productivity/dataservice/login_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _heartbeatTimer;

  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  Future<void> init() async {
    if (_isConnected) return;

    final token = await LoginService.getToken();
    if (token == null) return;

    final baseUrl = ApiClient.baseUrl; 
    final uri = Uri.parse(baseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final wsUrl = '$wsScheme://${uri.host}:${uri.port}${uri.path}/chat/ws/notifications?token=$token';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;

      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (_isConnected) _channel?.sink.add('ping');
      });

      _channel!.stream.listen(
        (event) {
          _handleNotification(event);
        },
        onDone: () {
          _isConnected = false;
          _heartbeatTimer?.cancel();
          Future.delayed(const Duration(seconds: 5), () => init());
        },
        onError: (e) {
          _isConnected = false;
          _heartbeatTimer?.cancel();
          Future.delayed(const Duration(seconds: 5), () => init());
        },
      );
    } catch (e) {
      _isConnected = false;
    }
  }

  void _handleNotification(dynamic event) {
    if (event == 'pong' || event == 'ping') return;
    try {
      final data = jsonDecode(event.toString());
      if (data['type'] == 'notification') {
        _showInAppNotification(
          data['title'] ?? 'Neue Nachricht',
          data['body'] ?? 'Du hast eine neue Nachricht.',
          data['chatId'],
        );
      }
    } catch (e) {}
  }

  void _showInAppNotification(String title, String body, String? chatId) {
    final state = messengerKey.currentState;
    if (state == null) return;

    // Kein clearSnackBars() mehr hier, um AnimationController Fehler zu vermeiden
    state.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.chat_bubble_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(body, style: const TextStyle(color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blueAccent.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
  }
}

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

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  Future<void> init() async {
    if (_isConnected) return;

    final token = await LoginService.getToken();
    if (token == null) return;

    final baseUrl = ApiClient.baseUrl;
    final uri = Uri.parse(baseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final port = uri.hasPort ? ':${uri.port}' : '';
    final wsUrl =
        '$wsScheme://${uri.host}$port${uri.path}/chat/ws/notifications?token=$token';

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

      // Handle Chat Notifications
      if (data['type'] == 'notification') {
        _showInAppNotification(
          data['title'] ?? 'Neue Nachricht',
          data['body'] ?? 'Du hast eine neue Nachricht.',
          data['chatId'],
          icon: Icons.chat_bubble_outline,
          backgroundColor: Colors.blueAccent.shade700,
        );
      }
      // Handle Pantry Expiry Warnings
      else if (data['type'] == 'pantry_expiry_warning') {
        _showPantryExpiryWarning(data);
      }
      // Handle Pantry Expired Items
      else if (data['type'] == 'pantry_expiry_expired') {
        _showPantryExpired(data);
      }
    } catch (e) {}
  }

  void _showPantryExpiryWarning(Map<String, dynamic> data) {
    final title = data['title'] ?? '⚠️ Vorrat läuft ab!';
    final body = data['body'] ?? 'Ein Vorrat läuft in Kürze ab.';
    final daysUntilExpiry = data['daysUntilExpiry'] ?? 0;

    String timeText;
    if (daysUntilExpiry == 0) {
      timeText = 'heute';
    } else if (daysUntilExpiry == 1) {
      timeText = 'morgen';
    } else {
      timeText = 'in $daysUntilExpiry Tagen';
    }

    _showInAppNotification(
      title,
      '$body ($timeText)',
      null,
      icon: Icons.warning_amber_rounded,
      backgroundColor: Colors.orange.shade600,
    );
  }

  void _showPantryExpired(Map<String, dynamic> data) {
    final title = data['title'] ?? '❌ Vorrat abgelaufen!';
    final body = data['body'] ?? 'Ein Vorrat ist abgelaufen.';
    final daysSinceExpiry = data['daysSinceExpiry'] ?? 0;

    final timeText = daysSinceExpiry == 1
        ? 'seit 1 Tag'
        : 'seit $daysSinceExpiry Tagen';

    _showInAppNotification(
      title,
      '$body ($timeText)',
      null,
      icon: Icons.error_rounded,
      backgroundColor: Colors.red.shade600,
    );
  }

  void _showInAppNotification(
    String title,
    String body,
    String? chatId, {
    IconData icon = Icons.chat_bubble_outline,
    Color backgroundColor = const Color(0xFF1976D2),
  }) {
    final state = messengerKey.currentState;
    if (state == null) return;

    state.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    body,
                    style: const TextStyle(color: Colors.white70),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
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

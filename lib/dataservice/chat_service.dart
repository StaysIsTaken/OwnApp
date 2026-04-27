import 'dart:convert';
import 'package:productivity/dataclasses/chat.dart';
import 'package:productivity/dataclasses/User.dart';
import 'package:productivity/dataservice/api_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatService {
  ChatService._();

  static const String _basePath = '/chat';

  // --- REST: History & Rooms ---

  /// Lädt alle Chaträume des Users
  static Future<List<ChatRoom>> getRooms() async {
    final response = await ApiClient.dio.get('$_basePath/rooms');
    // Die API gibt hier direkt eine Liste zurück (basierend auf list[ChatRoomOut])
    final list = response.data as List<dynamic>;
    return list.map((e) => ChatRoom.fromJson(e)).toList();
  }

  /// Lädt die letzten Nachrichten eines Raums
  static Future<List<ChatMessage>> getMessages(String chatId) async {
    final response = await ApiClient.dio.get('$_basePath/rooms/$chatId/messages');
    final list = response.data as List<dynamic>;
    return list.map((e) => ChatMessage.fromJson(e)).toList();
  }

  /// Erstellt einen neuen Chatraum
  static Future<ChatRoom> createRoom(String name, bool isGroup, List<String> memberIds) async {
    final response = await ApiClient.dio.post('$_basePath/rooms', data: {
      'name': name,
      'isGroup': isGroup,
      'memberIds': memberIds, // Gemäß ChatRoomCreate Schema
    });
    return ChatRoom.fromJson(response.data);
  }

  /// Aktualisiert einen Chatraum
  static Future<ChatRoom> updateRoom(String chatId, String name) async {
    final response = await ApiClient.dio.put('$_basePath/rooms/$chatId', data: {'name': name});
    return ChatRoom.fromJson(response.data);
  }

  /// Verlässt einen Chatraum
  static Future<void> deleteRoom(String chatId) async {
    await ApiClient.dio.delete('$_basePath/rooms/$chatId');
  }

  // --- Members ---

  /// Fügt ein Mitglied hinzu (via Pfad-Parameter)
  static Future<void> addMember(String chatId, String userId) async {
    await ApiClient.dio.post('$_basePath/rooms/$chatId/members/$userId');
  }

  /// Entfernt ein Mitglied (via Pfad-Parameter)
  static Future<void> removeMember(String chatId, String userId) async {
    await ApiClient.dio.delete('$_basePath/rooms/$chatId/members/$userId');
  }

  /// Lädt alle Mitglieder eines Raums (gibt User-Objekte zurück)
  static Future<List<User>> getMembers(String chatId) async {
    final response = await ApiClient.dio.get('$_basePath/rooms/$chatId/members');
    final list = response.data as List<dynamic>;
    return list.map((e) => User.fromJson(e)).toList();
  }

  // --- WebSocket: Real-time ---

  static WebSocketChannel connect(String chatId, String token) {
    final baseUrl = ApiClient.dio.options.baseUrl;
    final uri = Uri.parse(baseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final wsUrl = '$wsScheme://${uri.host}:${uri.port}/api/chat/ws/$chatId?token=$token';
    return WebSocketChannel.connect(Uri.parse(wsUrl));
  }
}

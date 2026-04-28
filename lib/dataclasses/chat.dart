class ChatRoom {
  final String id;
  final String? name;
  final bool isGroup;
  final String? creatorId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final LastMessageInfo? lastMessage;
  final String? otherParticipantName;

  ChatRoom({
    required this.id,
    this.name,
    required this.isGroup,
    this.creatorId,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.otherParticipantName,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id']?.toString() ?? '',
      name: json['name'],
      isGroup: json['isGroup'] == true || json['isGroup'] == 1,
      creatorId: json['creatorId']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      lastMessage: json['lastMessage'] != null ? LastMessageInfo.fromJson(json['lastMessage']) : null,
      otherParticipantName: json['otherParticipantName'],
    );
  }

  /// Gibt den anzuzeigenden Namen für den Chat zurück
  String get displayName {
    if (isGroup) return name ?? 'Gruppe';
    return otherParticipantName ?? 'Unbekannter User';
  }
}

class LastMessageInfo {
  final String message;
  final String? senderName;
  final DateTime createdAt;

  LastMessageInfo({
    required this.message,
    this.senderName,
    required this.createdAt,
  });

  factory LastMessageInfo.fromJson(Map<String, dynamic> json) {
    return LastMessageInfo(
      message: json['message']?.toString() ?? '',
      senderName: json['senderName'],
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class ChatMember {
  final String id;
  final String chatId;
  final String userId;
  final DateTime joined;

  ChatMember({
    required this.id,
    required this.chatId,
    required this.userId,
    required this.joined,
  });

  factory ChatMember.fromJson(Map<String, dynamic> json) {
    return ChatMember(
      id: json['id']?.toString() ?? '',
      chatId: json['chatId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      joined: DateTime.tryParse(json['joined']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String? senderName;
  final bool isRead;
  final DateTime createdAt;
  final String message;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.senderName,
    required this.isRead,
    required this.createdAt,
    required this.message,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      chatId: json['chatId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderName: json['senderName'],
      isRead: json['isRead'] == true || json['isRead'] == 1,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      message: json['message']?.toString() ?? '',
    );
  }
}

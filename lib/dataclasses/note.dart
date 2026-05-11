class Note {
  final String id;
  final String userId;
  final String title;
  final String text;
  final String? folderId;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;

  Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.text,
    this.folderId,
    this.tags = const [],
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    List<String> parsedTags = [];
    if (json['tags'] != null) {
      if (json['tags'] is String) {
        parsedTags = (json['tags'] as String)
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList();
      } else if (json['tags'] is List) {
        parsedTags = List<String>.from(json['tags']);
      }
    }

    return Note(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? '',
      text: json['text'] ?? '',
      folderId: json['folderId'],
      tags: parsedTags,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      isDeleted: json['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'text': text,
      'folderId': folderId,
      'tags': formatTags(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'isDeleted': isDeleted,
    };
  }

  Note copyWith({
    String? id,
    String? userId,
    String? title,
    String? text,
    String? folderId,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Note(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      text: text ?? this.text,
      folderId: folderId ?? this.folderId,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  String formatTags() => tags.join(',');

  static List<String> parseTags(String tagsString) {
    return tagsString
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  List<String> extractBacklinks() {
    final regex = RegExp(r'\[\[([^\]]+)\]\]');
    final matches = regex.allMatches(text);
    return matches.map((match) => match.group(1) ?? '').toList();
  }

  bool hasBacklinkTo(String targetTitle) {
    return extractBacklinks().contains(targetTitle);
  }
}

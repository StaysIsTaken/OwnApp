class JournalEntry {
  final String id;
  final String userId;
  final String content;
  final DateTime date;
  final DateTime createdAt;
  final DateTime? updatedAt;

  JournalEntry({
    required this.id,
    required this.userId,
    required this.content,
    required this.date,
    required this.createdAt,
    this.updatedAt,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      content: json['content'] ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'content': content,
      'date': date.toIso8601String().split('T')[0],
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  JournalEntry copyWith({
    String? id,
    String? userId,
    String? content,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

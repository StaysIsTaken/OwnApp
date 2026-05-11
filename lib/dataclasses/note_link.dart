class NoteLink {
  final String id;
  final String sourceNoteId;
  final String targetNoteId;
  final DateTime createdAt;

  NoteLink({
    required this.id,
    required this.sourceNoteId,
    required this.targetNoteId,
    required this.createdAt,
  });

  factory NoteLink.fromJson(Map<String, dynamic> json) {
    return NoteLink(
      id: json['id'] ?? '',
      sourceNoteId: json['sourceNoteId'] ?? '',
      targetNoteId: json['targetNoteId'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourceNoteId': sourceNoteId,
      'targetNoteId': targetNoteId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

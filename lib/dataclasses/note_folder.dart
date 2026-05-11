class NoteFolder {
  final String id;
  final String userId;
  final String name;
  final String? parentFolderId;
  final DateTime createdAt;

  NoteFolder({
    required this.id,
    required this.userId,
    required this.name,
    this.parentFolderId,
    required this.createdAt,
  });

  factory NoteFolder.fromJson(Map<String, dynamic> json) {
    return NoteFolder(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      parentFolderId: json['parentFolderId'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'parentFolderId': parentFolderId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  NoteFolder copyWith({
    String? id,
    String? userId,
    String? name,
    String? parentFolderId,
    DateTime? createdAt,
  }) {
    return NoteFolder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      parentFolderId: parentFolderId ?? this.parentFolderId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class Shop {
  final String id;
  final String name;
  final DateTime createdAt;

  Shop({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'].toString(),
      name: json['name'] as String,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Shop copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
  }) {
    return Shop(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

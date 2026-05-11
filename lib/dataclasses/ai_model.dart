class AIModel {
  final String name;
  final DateTime modifiedAt;
  final int size;

  AIModel({
    required this.name,
    required this.modifiedAt,
    required this.size,
  });

  factory AIModel.fromJson(Map<String, dynamic> json) {
    return AIModel(
      name: json['name'] ?? '',
      modifiedAt: json['modified_at'] != null
          ? DateTime.parse(json['modified_at'])
          : DateTime.now(),
      size: json['size'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'modified_at': modifiedAt.toIso8601String(),
      'size': size,
    };
  }

  String getFormattedSize() {
    const int gb = 1000000000;
    const int mb = 1000000;
    const int kb = 1000;

    if (size >= gb) {
      return '${(size / gb).toStringAsFixed(2)} GB';
    } else if (size >= mb) {
      return '${(size / mb).toStringAsFixed(2)} MB';
    } else if (size >= kb) {
      return '${(size / kb).toStringAsFixed(2)} KB';
    } else {
      return '$size B';
    }
  }
}

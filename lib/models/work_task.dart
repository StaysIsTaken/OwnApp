import 'dart:convert';

// ─────────────────────────────────────────────
//  Data Model – WorkTask
// ─────────────────────────────────────────────
class WorkTask {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final String description;

  const WorkTask({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.description,
  });

  /// Returns the duration between start and end, or null if still running.
  Duration? get duration =>
      endTime != null ? endTime!.difference(startTime) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'description': description,
      };

  factory WorkTask.fromJson(Map<String, dynamic> json) => WorkTask(
        id: json['id'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: json['endTime'] != null
            ? DateTime.parse(json['endTime'] as String)
            : null,
        description: json['description'] as String,
      );

  String toJsonString() => jsonEncode(toJson());

  factory WorkTask.fromJsonString(String s) =>
      WorkTask.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

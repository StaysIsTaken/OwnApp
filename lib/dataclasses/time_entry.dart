// ─────────────────────────────────────────────
//  TimeEntry – Zeiterfassungs-Eintrag
// ─────────────────────────────────────────────
class TimeEntry {
  final String id;
  final String? userId;
  final DateTime date;
  final DateTime startTime;
  final DateTime? endTime;
  final String description;

  TimeEntry({
    required this.id,
    this.userId,
    required this.date,
    required this.startTime,
    this.endTime,
    required this.description,
  });

  Duration get duration {
    if (endTime == null) return Duration.zero;
    return endTime!.difference(startTime);
  }

  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  factory TimeEntry.fromJson(Map<String, dynamic> json) {
    return TimeEntry(
      id: json['id'].toString(),
      userId: json['userId'] as String?,
      date: DateTime.parse(json['date'] as String),
      startTime: DateTime.parse(json['start'] as String),
      endTime: json['end'] != null
          ? DateTime.parse(json['end'] as String)
          : null,
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'userId': userId,
      'date': "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}", // Ensure date-only format for backend date field
      'start': startTime.toIso8601String(),
      'end': endTime?.toIso8601String(),
      'description': description,
    };
  }

  TimeEntry copyWith({
    String? id,
    String? userId,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    bool clearEndTime = false,
    String? description,
  }) {
    return TimeEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      description: description ?? this.description,
    );
  }
}

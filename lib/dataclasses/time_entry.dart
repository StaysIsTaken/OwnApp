class TimeEntry {
  final String id;
  final DateTime date;
  final DateTime startTime;
  final DateTime? endTime;
  final String description;

  TimeEntry({
    required this.id,
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
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'description': description,
    };
  }

  TimeEntry copyWith({
    String? id,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    String? description,
  }) {
    return TimeEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      description: description ?? this.description,
    );
  }
}

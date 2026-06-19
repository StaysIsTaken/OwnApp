class PlannerEntry {
  final int id;
  final String userId;
  final String title;
  final String? description;
  final int? typeId;
  final String? type;
  final int? recurrenceId;
  final bool isDetached;
  final DateTime scheduledAt;
  final DateTime endsAt;
  final int durationMin;
  final bool notified;
  final int notifyMinBefore;
  final int orderIndex;
  final String color;
  final DateTime createdAt;
  final int? parentId;
  final List<PlannerEntry> children;

  PlannerEntry({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.typeId,
    this.type,
    this.recurrenceId,
    this.isDetached = false,
    required this.scheduledAt,
    required this.endsAt,
    this.durationMin = 60,
    this.notified = false,
    this.notifyMinBefore = 10,
    this.orderIndex = 0,
    this.color = '#3B82F6',
    required this.createdAt,
    this.parentId,
    this.children = const [],
  });

  factory PlannerEntry.fromJson(Map<String, dynamic> json) {
    final scheduledAt = json['scheduled_at'] != null
        ? DateTime.parse(json['scheduled_at'])
        : DateTime.now();
    final durationMin = json['duration_min'] ?? 60;
    return PlannerEntry(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      typeId: json['type_id'],
      type: json['type'],
      recurrenceId: json['recurrence_id'],
      isDetached: json['is_detached'] ?? false,
      scheduledAt: scheduledAt,
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'])
          : scheduledAt.add(Duration(minutes: durationMin)),
      durationMin: durationMin,
      notified: json['notified'] ?? false,
      notifyMinBefore: json['notify_min_before'] ?? 10,
      orderIndex: json['order_index'] ?? 0,
      color: json['color'] ?? '#3B82F6',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      parentId: json['parent_id'],
      children: json['children'] != null
          ? (json['children'] as List)
              .map((c) => PlannerEntry.fromJson(c as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'type_id': typeId,
      'type': type,
      'scheduled_at': scheduledAt.toIso8601String(),
      'ends_at': endsAt.toIso8601String(),
      'duration_min': durationMin,
      'notified': notified,
      'notify_min_before': notifyMinBefore,
      'order_index': orderIndex,
      'color': color,
      'created_at': createdAt.toIso8601String(),
      'parent_id': parentId,
      'children': children.map((c) => c.toJson()).toList(),
    };
  }

  PlannerEntry copyWith({
    int? id,
    String? userId,
    String? title,
    String? description,
    int? typeId,
    String? type,
    int? recurrenceId,
    bool? isDetached,
    DateTime? scheduledAt,
    DateTime? endsAt,
    int? durationMin,
    bool? notified,
    int? notifyMinBefore,
    int? orderIndex,
    String? color,
    DateTime? createdAt,
    int? parentId,
    List<PlannerEntry>? children,
  }) {
    return PlannerEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      typeId: typeId ?? this.typeId,
      type: type ?? this.type,
      recurrenceId: recurrenceId ?? this.recurrenceId,
      isDetached: isDetached ?? this.isDetached,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      endsAt: endsAt ?? this.endsAt,
      durationMin: durationMin ?? this.durationMin,
      notified: notified ?? this.notified,
      notifyMinBefore: notifyMinBefore ?? this.notifyMinBefore,
      orderIndex: orderIndex ?? this.orderIndex,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      parentId: parentId ?? this.parentId,
      children: children ?? this.children,
    );
  }

  bool get isOverdue => scheduledAt.isBefore(DateTime.now()) && !notified;
  bool get isToday => _isSameDay(scheduledAt, DateTime.now());
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(Duration(days: 1));
    return _isSameDay(scheduledAt, tomorrow);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int get minutesUntilStart {
    return scheduledAt.difference(DateTime.now()).inMinutes;
  }

  int get minutesUntilNotification {
    return (scheduledAt.difference(DateTime.now()).inMinutes) - notifyMinBefore;
  }
}

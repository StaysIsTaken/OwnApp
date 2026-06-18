class PlannerEntry {
  final int id;
  final String userId;
  final String title;
  final String? description;
  final String type;
  final DateTime scheduledAt;
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
    required this.type,
    required this.scheduledAt,
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
    return PlannerEntry(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      type: json['type'] ?? 'task',
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'])
          : DateTime.now(),
      durationMin: json['duration_min'] ?? 60,
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
      'type': type,
      'scheduled_at': scheduledAt.toIso8601String(),
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
    String? type,
    DateTime? scheduledAt,
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
      type: type ?? this.type,
      scheduledAt: scheduledAt ?? this.scheduledAt,
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

class Task {
  final String id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final bool completed;
  final String? category;
  final String priority;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String kanbanState;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.completed = false,
    this.category,
    this.priority = 'medium',
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.kanbanState = 'todo',
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'].toString(),
      title: json['title'] as String,
      description: json['description'] as String?,
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
      completed: json['completed'] as bool? ?? false,
      category: json['category'] as String?,
      priority: json['priority'] as String? ?? 'medium',
      userId: json['userId'].toString(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      kanbanState: json['kanbanState'] as String? ?? 'todo',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      if (dueDate != null) 'dueDate': dueDate!.toIso8601String().split('T')[0],
      'completed': completed,
      if (category != null) 'category': category,
      'priority': priority,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'kanbanState': kanbanState,
    };
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    bool? completed,
    String? category,
    String? priority,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? kanbanState,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      completed: completed ?? this.completed,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      kanbanState: kanbanState ?? this.kanbanState,
    );
  }
}

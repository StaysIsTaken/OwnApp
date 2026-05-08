class SubTask {
  final String id;
  final String taskId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final bool completed;
  final String? category;
  final String priority;
  final DateTime createdAt;
  final DateTime updatedAt;

  SubTask({
    required this.id,
    required this.taskId,
    required this.title,
    this.description,
    this.dueDate,
    this.completed = false,
    this.category,
    this.priority = 'medium',
    required this.createdAt,
    required this.updatedAt,
  });

  factory SubTask.fromJson(Map<String, dynamic> json) {
    return SubTask(
      id: json['id'].toString(),
      taskId: json['taskId'].toString(),
      title: json['title'] as String,
      description: json['description'] as String?,
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
      completed: json['completed'] as bool? ?? false,
      category: json['category'] as String?,
      priority: json['priority'] as String? ?? 'medium',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'title': title,
      if (description != null) 'description': description,
      if (dueDate != null) 'dueDate': dueDate!.toIso8601String().split('T')[0],
      'completed': completed,
      if (category != null) 'category': category,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  SubTask copyWith({
    String? id,
    String? taskId,
    String? title,
    String? description,
    DateTime? dueDate,
    bool? completed,
    String? category,
    String? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubTask(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      completed: completed ?? this.completed,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

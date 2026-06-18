class PlannerEntryType {
  final int id;
  final String userId;
  final String name;
  final String color;
  final String? icon;
  final int orderIndex;

  PlannerEntryType({
    required this.id,
    required this.userId,
    required this.name,
    this.color = '#3B82F6',
    this.icon,
    this.orderIndex = 0,
  });

  factory PlannerEntryType.fromJson(Map<String, dynamic> json) {
    return PlannerEntryType(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      color: json['color'] ?? '#3B82F6',
      icon: json['icon'],
      orderIndex: json['order_index'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'color': color,
      'icon': icon,
      'order_index': orderIndex,
    };
  }
}

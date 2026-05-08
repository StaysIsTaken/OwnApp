class ShoppingListItemPrice {
  final String id;
  final String shoppingListItemId;
  final String shopId;
  final double price;
  final DateTime date;

  ShoppingListItemPrice({
    required this.id,
    required this.shoppingListItemId,
    required this.shopId,
    required this.price,
    required this.date,
  });

  factory ShoppingListItemPrice.fromJson(Map<String, dynamic> json) {
    final dateStr = json['date'] as String?;
    final parsedDate = dateStr != null
        ? DateTime.parse(dateStr.contains('T') ? dateStr : '${dateStr}T00:00:00')
        : DateTime.now();

    return ShoppingListItemPrice(
      id: json['id'].toString(),
      shoppingListItemId: json['shoppingListItemId'].toString(),
      shopId: json['shopId'].toString(),
      price: (json['price'] as num).toDouble(),
      date: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shoppingListItemId': shoppingListItemId,
      'shopId': shopId,
      'price': price,
      'date': date.toIso8601String().split('T')[0],
    };
  }

  ShoppingListItemPrice copyWith({
    String? id,
    String? shoppingListItemId,
    String? shopId,
    double? price,
    DateTime? date,
  }) {
    return ShoppingListItemPrice(
      id: id ?? this.id,
      shoppingListItemId: shoppingListItemId ?? this.shoppingListItemId,
      shopId: shopId ?? this.shopId,
      price: price ?? this.price,
      date: date ?? this.date,
    );
  }
}

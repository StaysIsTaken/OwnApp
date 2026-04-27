import 'dart:convert';

// ─────────────────────────────────────────────
//  PantryItem (Vorratsartikel)
// ─────────────────────────────────────────────
class PantryItem {
  final String id;
  final String ingredientId;
  final String unitId;
  final String? storageLocationId;
  final double amount; // Match DB: amount
  final double minAmount; // Match DB: minAmount
  final DateTime? expiryDate;
  final DateTime updatedAt;

  const PantryItem({
    required this.id,
    required this.ingredientId,
    required this.unitId,
    this.storageLocationId,
    required this.amount,
    required this.minAmount,
    this.expiryDate,
    required this.updatedAt,
  });

  PantryItem copyWith({
    String? id,
    String? ingredientId,
    String? unitId,
    String? storageLocationId,
    double? amount,
    double? minAmount,
    DateTime? expiryDate,
    DateTime? updatedAt,
  }) =>
      PantryItem(
        id: id ?? this.id,
        ingredientId: ingredientId ?? this.ingredientId,
        unitId: unitId ?? this.unitId,
        storageLocationId: storageLocationId ?? this.storageLocationId,
        amount: amount ?? this.amount,
        minAmount: minAmount ?? this.minAmount,
        expiryDate: expiryDate ?? this.expiryDate,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'ingredientId': ingredientId,
        'unitId': unitId,
        'storageLocationId': storageLocationId,
        'amount': amount,
        'minAmount': minAmount,
        'expiryDate': expiryDate?.toIso8601String().split('T')[0],
      };

  factory PantryItem.fromJson(Map<String, dynamic> j) {
    return PantryItem(
      id: j['id']?.toString() ?? '',
      ingredientId: (j['ingredientId'] ?? '').toString(),
      unitId: (j['unitId'] ?? '').toString(),
      storageLocationId: j['storageLocationId']?.toString(),
      amount: (j['amount'] as num?)?.toDouble() ?? (j['quantity'] as num?)?.toDouble() ?? 0.0,
      minAmount: (j['minAmount'] as num?)?.toDouble() ?? (j['minQuantity'] as num?)?.toDouble() ?? 0.0,
      expiryDate: j['expiryDate'] != null ? DateTime.tryParse(j['expiryDate'].toString()) : null,
      updatedAt: j['updatedAt'] != null 
          ? DateTime.tryParse(j['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

// ─────────────────────────────────────────────
//  StorageLocation (Lagerort)
// ─────────────────────────────────────────────
class StorageLocation {
  final String id;
  final String name;

  const StorageLocation({required this.id, required this.name});

  Map<String, dynamic> toJson() => {if (id.isNotEmpty) 'id': id, 'name': name};

  factory StorageLocation.fromJson(Map<String, dynamic> j) => StorageLocation(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? '',
  );
}

// ─────────────────────────────────────────────
//  ShoppingListItem (Einkaufsliste)
// ─────────────────────────────────────────────
class ShoppingListItem {
  final String id;
  final String ingredientId;
  final String unitId;
  final double amount;
  final bool isBought;
  final String? note;

  const ShoppingListItem({
    required this.id,
    required this.ingredientId,
    required this.unitId,
    required this.amount,
    this.isBought = false,
    this.note,
  });

  ShoppingListItem copyWith({
    String? id,
    String? ingredientId,
    String? unitId,
    double? amount,
    bool? isBought,
    String? note,
  }) => ShoppingListItem(
    id: id ?? this.id,
    ingredientId: ingredientId ?? this.ingredientId,
    unitId: unitId ?? this.unitId,
    amount: amount ?? this.amount,
    isBought: isBought ?? this.isBought,
    note: note ?? this.note,
  );

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    'ingredientId': ingredientId,
    // Leer heisst "keine Einheit", nicht "die Einheit mit leerem Namen".
    // Der Fremdschluessel lehnt einen leeren String ab, und der Server
    // stuerzt daran ab – im Browser kommt das als CORS-Fehler an, weil
    // ein abgestuerzter Server keine CORS-Kopfzeilen mehr setzt.
    if (unitId.isNotEmpty) 'unitId': unitId,
    'amount': amount,
    'isBought': isBought,
    'note': note,
  };

  factory ShoppingListItem.fromJson(Map<String, dynamic> j) => ShoppingListItem(
    id: j['id']?.toString() ?? '',
    ingredientId: (j['ingredientId'] ?? '').toString(),
    unitId: (j['unitId'] ?? '').toString(),
    amount: (j['amount'] as num?)?.toDouble() ?? 0.0,
    isBought: j['isBought'] ?? false,
    note: j['note']?.toString(),
  );
}

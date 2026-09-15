// ─────────────────────────────────────────────
//  MealPlanEntry (Eintrag im Essensplaner)
// ─────────────────────────────────────────────
class MealPlanEntry {
  final String id;
  final String recipeId;
  final DateTime date;
  final String? mealType;
  final int servings;

  /// Gesetzt: der Eintrag gehört dem Haushalt, nicht einer Person.
  final int? householdId;
  final String? ownerId;

  const MealPlanEntry({
    required this.id,
    required this.recipeId,
    required this.date,
    this.mealType,
    this.servings = 2,
    this.householdId,
    this.ownerId,
  });

  /// Ob er dem Haushalt gehört und nicht einer Person.
  bool get istUnseres => householdId != null;

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    'recipeId': recipeId,
    'date': date.toIso8601String().split('T')[0],
    'mealType': mealType,
    'servings': servings,
  };

  factory MealPlanEntry.fromJson(Map<String, dynamic> j) => MealPlanEntry(
    id: j['id']?.toString() ?? '',
    recipeId: (j['recipeId'] ?? '').toString(),
    date: DateTime.tryParse(j['date']?.toString() ?? '') ?? DateTime.now(),
    mealType: j['mealType']?.toString(),
    servings: j['servings'] as int? ?? 2,
    householdId: (j['household_id'] as num?)?.toInt(),
    ownerId: j['owner_id']?.toString(),
  );
}

// ─────────────────────────────────────────────
//  PantryTransaction (Historie der Vorräte)
// ─────────────────────────────────────────────
class PantryTransaction {
  final String id;
  final String pantryItemId;
  final double amount;
  final String? reason;
  final DateTime timestamp;

  const PantryTransaction({
    required this.id,
    required this.pantryItemId,
    required this.amount,
    this.reason,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    'pantryItemId': pantryItemId,
    'amount': amount,
    'reason': reason,
  };

  factory PantryTransaction.fromJson(Map<String, dynamic> j) =>
      PantryTransaction(
        id: j['id']?.toString() ?? '',
        pantryItemId: (j['pantryItemId'] ?? '').toString(),
        amount: (j['amount'] as num?)?.toDouble() ?? 0.0,
        reason: j['reason']?.toString(),
        timestamp:
            DateTime.tryParse(j['timestamp']?.toString() ?? '') ??
            DateTime.now(),
      );
}

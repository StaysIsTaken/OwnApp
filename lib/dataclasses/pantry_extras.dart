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

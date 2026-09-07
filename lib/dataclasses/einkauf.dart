/// Eine Einkaufsliste.
///
/// Sie gehört jemandem; wer hinzugefügt wurde, schreibt mit. Anders als
/// früher gibt es nicht mehr *die* Einkaufsliste, sondern so viele, wie man
/// braucht — Wochenkauf und Baumarkt gehören nicht auf denselben Zettel.
class Einkaufsliste {
  final int id;
  final String ownerId;
  final String ownerName;
  final String name;
  final String color;
  final int orderIndex;

  /// Wer außer dem Besitzer mitschreiben darf.
  final List<String> memberIds;

  /// Wie viel offen ist — kommt mit, damit die Übersicht das zeigen kann,
  /// ohne jede Liste einzeln zu laden.
  final int offen;
  final int erledigt;

  const Einkaufsliste({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.name,
    this.color = '#3B82F6',
    this.orderIndex = 0,
    this.memberIds = const [],
    this.offen = 0,
    this.erledigt = 0,
  });

  bool gehoert(String userId) => ownerId == userId;

  factory Einkaufsliste.fromJson(Map<String, dynamic> j) => Einkaufsliste(
        id: (j['id'] as num).toInt(),
        ownerId: j['owner_id']?.toString() ?? '',
        ownerName: j['owner_name']?.toString() ?? '',
        name: j['name']?.toString() ?? 'Einkauf',
        color: j['color']?.toString() ?? '#3B82F6',
        orderIndex: (j['order_index'] as num?)?.toInt() ?? 0,
        memberIds: [
          for (final m in (j['member_ids'] as List<dynamic>? ?? const []))
            m.toString(),
        ],
        offen: (j['open_count'] as num?)?.toInt() ?? 0,
        erledigt: (j['done_count'] as num?)?.toInt() ?? 0,
      );
}

/// Eine Position auf einer Liste.
///
/// Der Name genügt. Menge, Einheit und Zutat sind freiwillig — „Milch" ist
/// eine vollständige Position. Genau daran krankte das alte System: dort
/// brauchte jeder Posten eine Zutat, eine Einheit und eine Menge.
class Einkaufsposition {
  final int id;
  final int listId;
  final String name;
  final double? menge;
  final String? ingredientId;
  final String? unitId;
  final String? notiz;
  final bool erledigt;
  final int orderIndex;

  const Einkaufsposition({
    required this.id,
    required this.listId,
    required this.name,
    this.menge,
    this.ingredientId,
    this.unitId,
    this.notiz,
    this.erledigt = false,
    this.orderIndex = 0,
  });

  /// Was unter dem Namen steht — Menge, Einheit, Notiz, soweit vorhanden.
  /// Leer, wenn es nichts zu sagen gibt; dann fällt die Zeile ganz weg.
  String beischrift(String Function(String)? einheitsname) {
    final teile = <String>[];
    if (menge != null) {
      final zahl = menge! % 1 == 0
          ? menge!.toInt().toString()
          : menge!.toStringAsFixed(1);
      final einheit = unitId == null ? '' : (einheitsname?.call(unitId!) ?? '');
      teile.add(einheit.isEmpty ? zahl : '$zahl $einheit');
    }
    if (notiz?.trim().isNotEmpty == true) teile.add(notiz!.trim());
    return teile.join(' · ');
  }

  Einkaufsposition copyWith({bool? erledigt}) => Einkaufsposition(
        id: id,
        listId: listId,
        name: name,
        menge: menge,
        ingredientId: ingredientId,
        unitId: unitId,
        notiz: notiz,
        erledigt: erledigt ?? this.erledigt,
        orderIndex: orderIndex,
      );

  factory Einkaufsposition.fromJson(Map<String, dynamic> j) =>
      Einkaufsposition(
        id: (j['id'] as num).toInt(),
        listId: (j['list_id'] as num).toInt(),
        name: j['name']?.toString() ?? '',
        menge: (j['amount'] as num?)?.toDouble(),
        ingredientId: j['ingredient_id']?.toString(),
        unitId: j['unit_id']?.toString(),
        notiz: j['note']?.toString(),
        erledigt: j['is_done'] == true,
        orderIndex: (j['order_index'] as num?)?.toInt() ?? 0,
      );
}

/// Was eine Ware wo gekostet hat.
///
/// Hängt an der Bezeichnung, nicht an einem Listeneintrag — deshalb
/// überlebt das Wissen den Einkauf.
class Warenpreis {
  final int id;
  final String bezeichnung;
  final String shopId;
  final String shopName;
  final double preis;
  final double? menge;
  final String? unitId;
  final DateTime? notiertAm;

  const Warenpreis({
    required this.id,
    required this.bezeichnung,
    required this.shopId,
    required this.shopName,
    required this.preis,
    this.menge,
    this.unitId,
    this.notiertAm,
  });

  factory Warenpreis.fromJson(Map<String, dynamic> j) => Warenpreis(
        id: (j['id'] as num).toInt(),
        bezeichnung: j['bezeichnung']?.toString() ?? '',
        shopId: j['shop_id']?.toString() ?? '',
        shopName: j['shop_name']?.toString() ?? '?',
        preis: (j['price'] as num?)?.toDouble() ?? 0,
        menge: (j['amount'] as num?)?.toDouble(),
        unitId: j['unit_id']?.toString(),
        notiertAm: j['noted_at'] == null
            ? null
            : DateTime.tryParse(j['noted_at'].toString()),
      );

  /// „0,89 €" beziehungsweise „2,49 € / 500" – der Preis allein sagt zu
  /// wenig, wenn er für eine Menge galt.
  String alsText([String? einheit]) {
    final euro = '${preis.toStringAsFixed(2).replaceAll('.', ',')} €';
    if (menge == null) return euro;
    final m = menge! % 1 == 0
        ? menge!.toInt().toString()
        : menge!.toStringAsFixed(1);
    return einheit == null || einheit.isEmpty
        ? '$euro / $m'
        : '$euro / $m $einheit';
  }
}

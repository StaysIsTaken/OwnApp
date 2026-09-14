/// Wer einen fremden Kalender lesen darf — und wovon nur einen Ausschnitt.
///
/// Der Gegenentwurf zum alten Modell: dort entschied ein Recht, dass
/// jemand alle Kalender sieht. Hier entscheidet der Besitzer, je Kalender
/// und je Person.
///
/// Beide Filter sind freiwillig und wirken zusammen (UND). Leer heißt
/// „alles aus diesem Kalender" — außer Privatem, denn das sieht niemand
/// außer dem Eigentümer.
class KalenderFreigabe {
  final int kalenderId;
  final String userId;

  /// Anzeigename der Person — der Server schickt ihn mit, damit die Liste
  /// nicht für jede Zeile die Nutzerliste durchsuchen muss.
  final String userName;

  /// Termintypen, die durchgelassen werden. Leer heißt: alle.
  final List<int> typIds;

  /// Muss im Titel vorkommen. Leer heißt: egal.
  final String? stichwort;

  const KalenderFreigabe({
    required this.kalenderId,
    required this.userId,
    required this.userName,
    this.typIds = const [],
    this.stichwort,
  });

  bool get hatFilter => typIds.isNotEmpty || (stichwort?.isNotEmpty ?? false);

  factory KalenderFreigabe.fromJson(Map<String, dynamic> j) => KalenderFreigabe(
        kalenderId: (j['calendar_id'] as num?)?.toInt() ?? 0,
        userId: j['user_id']?.toString() ?? '',
        userName: j['user_name']?.toString() ?? '?',
        typIds: ((j['filter_type_ids'] as List<dynamic>?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        stichwort: (j['filter_keyword']?.toString().isEmpty ?? true)
            ? null
            : j['filter_keyword'].toString(),
      );
}

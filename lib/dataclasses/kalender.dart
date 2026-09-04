/// Ein Kalender als eigenes Objekt.
///
/// Vorher waren Termine einfach Termine — jetzt liegen sie in einem
/// Kalender, und der gehört jemandem. Das ist der Unterschied, auf den es
/// ankommt: die Müllabfuhr ist ein Kalender wie jeder andere, sie gehört
/// nur niemandem persönlich, und eine Seite kann ihn zeigen oder eben nicht.
class Kalender {
  final int id;
  final String ownerId;

  /// Name der Person, der er gehört — für die Auswahl, wenn mehrere
  /// Kalender denselben Namen tragen ("Privat" gibt es zweimal im Haushalt).
  final String ownerName;

  final String name;
  final String color;
  final String? icon;

  /// Der Kalender, in dem Termine ohne eigene Angabe landen. Jeder hat
  /// genau einen; er lässt sich nicht löschen.
  final bool istStandard;

  /// Hinterlegte ICS-Adresse — daran erkennt man einen abonnierten Kalender
  /// (Müllabfuhr, Feiertage) gegenüber einem selbst gepflegten.
  final String? icsUrl;

  final DateTime? zuletztGeholt;
  final int anzahlTermine;

  const Kalender({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.name,
    required this.color,
    this.icon,
    this.istStandard = false,
    this.icsUrl,
    this.zuletztGeholt,
    this.anzahlTermine = 0,
  });

  bool get istAbonniert => icsUrl != null && icsUrl!.isNotEmpty;

  factory Kalender.fromJson(Map<String, dynamic> j) => Kalender(
        id: (j['id'] as num).toInt(),
        ownerId: j['owner_id']?.toString() ?? '',
        ownerName: j['owner_name']?.toString() ?? '',
        name: j['name']?.toString() ?? 'Kalender',
        color: j['color']?.toString() ?? '#3B82F6',
        icon: j['icon']?.toString(),
        istStandard: j['is_default'] == true,
        icsUrl: j['ics_url']?.toString(),
        zuletztGeholt: j['ics_synced_at'] == null
            ? null
            : DateTime.tryParse(j['ics_synced_at'].toString()),
        anzahlTermine: (j['entry_count'] as num?)?.toInt() ?? 0,
      );
}

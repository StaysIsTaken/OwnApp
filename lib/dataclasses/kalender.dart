/// Ein Kalender als eigenes Objekt.
///
/// Vorher waren Termine einfach Termine — jetzt liegen sie in einem
/// Kalender, und der gehört jemandem. Das ist der Unterschied, auf den es
/// ankommt: die Müllabfuhr ist ein Kalender wie jeder andere, sie gehört
/// nur niemandem persönlich, und eine Seite kann ihn zeigen oder eben nicht.
///
/// **Seit den Haushalten gibt es ihn zweimal**, und die beiden sind
/// verschieden:
///
/// * **persönlich** — gehört einer Person. Sein Besitzer kann ihn den
///   anderen im Haushalt zu lesen geben ([haushaltsFreigabe]).
/// * **gemeinsam** ([istHaushaltskalender]) — gehört dem Haushalt und
///   niemandem persönlich. Jedes Mitglied sieht ihn und trägt darin ein.
///
/// Was man mit ihm anfangen darf, steht deshalb **an ihm** und wird nicht
/// aus [ownerId] gerechnet: beim gemeinsamen Kalender steht dort niemand,
/// und `ownerId == meineId` wäre die falsche Antwort.
class Kalender {
  final int id;

  /// Leer beim gemeinsamen Kalender — der gehört keiner Person.
  final String? ownerId;

  /// Name der Person, der er gehört — für die Auswahl, wenn mehrere
  /// Kalender denselben Namen tragen ("Privat" gibt es zweimal im
  /// Haushalt). Beim gemeinsamen Kalender steht hier der Haushalt.
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

  /// Der Haushalt, dem er gehört. Nur am gemeinsamen Kalender gesetzt;
  /// am persönlichen sagt [haushaltsFreigabe], was der Haushalt sehen darf.
  final int? haushaltId;

  /// Der gemeinsame Kalender: gehört dem Haushalt, keiner Person.
  final bool istHaushaltskalender;

  /// „Die anderen im Haushalt dürfen mitlesen." Nur am persönlichen
  /// Kalender, gesetzt von seinem Besitzer in den Haushaltseinstellungen.
  final bool haushaltsFreigabe;

  /// Darf ich hier Termine eintragen? Der eigene und jeder gemeinsame.
  /// Ein fremder — auch ein freigegebener — nie: eine Freigabe öffnet zum
  /// Lesen.
  final bool darfSchreiben;

  /// Darf ich ihn umbenennen, einfärben, abholen? Dasselbe wie
  /// [darfSchreiben]; nur das Löschen des gemeinsamen Kalenders ist enger
  /// gefasst, und das sagt der Server beim Versuch.
  final bool darfVerwalten;

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
    this.haushaltId,
    this.istHaushaltskalender = false,
    this.haushaltsFreigabe = false,
    this.darfSchreiben = false,
    this.darfVerwalten = false,
  });

  bool get istAbonniert => icsUrl != null && icsUrl!.isNotEmpty;

  /// Gehört er mir persönlich? Nicht dasselbe wie [darfVerwalten]: den
  /// gemeinsamen Kalender darf ich verwalten, meiner ist er trotzdem nicht.
  bool gehoert(String? meineId) => ownerId != null && ownerId == meineId;

  factory Kalender.fromJson(Map<String, dynamic> j) => Kalender(
        id: (j['id'] as num).toInt(),
        ownerId: j['owner_id']?.toString(),
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
        haushaltId: (j['household_id'] as num?)?.toInt(),
        istHaushaltskalender: j['is_household'] == true,
        haushaltsFreigabe: j['household_share'] == true,
        // Vorgabe false: käme die Antwort von einem älteren Server, der
        // die Felder nicht kennt, wäre alles andere ein Versprechen, das
        // die App nicht halten kann. Dieselbe vorsichtige Richtung wie
        // bei [Finanzsicht.von].
        darfSchreiben: j['may_write'] == true,
        darfVerwalten: j['may_manage'] == true,
      );
}

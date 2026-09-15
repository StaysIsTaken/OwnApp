/// Das Haushaltsbuch: Kassen, Kategorien, Buchungen.
///
/// Zum Vorzeichen, weil es die häufigste Frage an diesen Klassen ist:
/// [Buchung.cents] ist **vorzeichenbehaftet**. Negativ ist eine Ausgabe,
/// positiv eine Einnahme. Eine Darstellung für beides, weil Gehalt und
/// Wocheneinkauf derselbe Vorgang sind — der Saldo ist dadurch eine
/// Summe und keine Fallunterscheidung.
///
/// Und alles in **Cent als Ganzzahl**. Ein Kassenbuch summiert über
/// Jahre; `double` driftet dabei um Beträge, die man danach sucht.
library;

/// Eine Kasse: „Haushalt", „Mein Giro", später ein echtes Bankkonto.
///
/// Sie gehört jemandem; wer hinzugefügt wurde, bucht mit — dasselbe
/// Muster wie bei den Einkaufslisten.
class Kasse {
  final int id;
  final String ownerId;
  final String ownerName;
  final String name;

  /// `bar`, `giro`, `sparen` oder `kreditkarte`.
  final String art;

  final String color;

  /// Anfangsbestand. Ohne ihn wäre [saldoCents] eine Summe von Buchungen
  /// und kein Kontostand.
  final int startCents;

  final int orderIndex;
  final List<String> memberIds;

  /// Kontostand inklusive Anfangsbestand — kommt vom Server mit, damit
  /// die Übersicht ihn zeigen kann, ohne jede Kasse nachzurechnen.
  final int saldoCents;

  const Kasse({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.name,
    this.art = 'giro',
    this.color = '#3B82F6',
    this.startCents = 0,
    this.orderIndex = 0,
    this.memberIds = const [],
    this.saldoCents = 0,
  });

  bool gehoert(String userId) => ownerId == userId;

  factory Kasse.fromJson(Map<String, dynamic> j) => Kasse(
        id: (j['id'] as num).toInt(),
        ownerId: j['owner_id']?.toString() ?? '',
        ownerName: j['owner_name']?.toString() ?? '',
        name: j['name']?.toString() ?? 'Kasse',
        art: j['kind']?.toString() ?? 'giro',
        color: j['color']?.toString() ?? '#3B82F6',
        startCents: (j['start_cents'] as num?)?.toInt() ?? 0,
        orderIndex: (j['order_index'] as num?)?.toInt() ?? 0,
        memberIds: [
          for (final m in (j['member_ids'] as List<dynamic>? ?? const []))
            m.toString(),
        ],
        saldoCents: (j['saldo_cents'] as num?)?.toInt() ?? 0,
      );
}

/// Wofür das Geld ausgegeben wurde.
///
/// Eigene Stammdaten, nicht die Kategorien der Aufgaben und Rezepte:
/// „Nudelgerichte" neben „Miete" wäre der Anfang einer Vermischung, die
/// im Backend schon einmal aufgetrennt werden musste.
class Finanzkategorie {
  final int id;
  final String name;

  /// `ausgabe`, `einnahme` oder `beides`.
  final String art;

  final String color;
  final String? icon;
  final int orderIndex;

  const Finanzkategorie({
    required this.id,
    required this.name,
    this.art = 'ausgabe',
    this.color = '#64748B',
    this.icon,
    this.orderIndex = 0,
  });

  /// Passt diese Kategorie zu einer Buchung dieser Richtung?
  bool passtZu({required bool ausgabe}) =>
      art == 'beides' || art == (ausgabe ? 'ausgabe' : 'einnahme');

  factory Finanzkategorie.fromJson(Map<String, dynamic> j) => Finanzkategorie(
        id: (j['id'] as num).toInt(),
        name: j['name']?.toString() ?? '',
        art: j['kind']?.toString() ?? 'ausgabe',
        color: j['color']?.toString() ?? '#64748B',
        icon: j['icon']?.toString(),
        orderIndex: (j['order_index'] as num?)?.toInt() ?? 0,
      );
}

/// Eine Buchung: hier ist Geld geflossen.
class Buchung {
  final int id;
  final int kasseId;
  final int? kategorieId;
  final DateTime tag;

  /// Negativ = Ausgabe, positiv = Einnahme.
  final int cents;

  final String titel;
  final String? notiz;

  /// Aus welchem Dauerauftrag sie stammt, falls aus einem.
  final int? serieId;

  /// Einzeln angefasst — das Nachbuchen rührt sie nicht mehr an.
  final bool abgekoppelt;

  const Buchung({
    required this.id,
    required this.kasseId,
    required this.tag,
    required this.cents,
    required this.titel,
    this.kategorieId,
    this.notiz,
    this.serieId,
    this.abgekoppelt = false,
  });

  bool get istAusgabe => cents < 0;
  bool get ausSerie => serieId != null;

  factory Buchung.fromJson(Map<String, dynamic> j) => Buchung(
        id: (j['id'] as num).toInt(),
        kasseId: (j['account_id'] as num).toInt(),
        kategorieId: (j['category_id'] as num?)?.toInt(),
        tag: DateTime.parse(j['booked_on'].toString()),
        cents: (j['amount_cents'] as num).toInt(),
        titel: j['title']?.toString() ?? '',
        notiz: j['note']?.toString(),
        serieId: (j['series_id'] as num?)?.toInt(),
        abgekoppelt: j['is_detached'] == true,
      );
}

/// Was ein Zeitraum an Geld gekostet und gebracht hat.
///
/// Im Backend gerechnet: die Kacheln der Übersicht brauchen genau diese
/// Zahlen, und viermal dieselbe Summe über alle Buchungen zu bilden wäre
/// Verschwendung.
class Auswertung {
  final DateTime von;
  final DateTime bis;
  final int einnahmenCents;

  /// **Positiv**, obwohl Ausgaben negativ gespeichert sind. Eine Torte
  /// kann mit negativen Werten nichts anfangen.
  final int ausgabenCents;

  final int saldoCents;
  final List<Kategoriesumme> jeKategorie;

  const Auswertung({
    required this.von,
    required this.bis,
    this.einnahmenCents = 0,
    this.ausgabenCents = 0,
    this.saldoCents = 0,
    this.jeKategorie = const [],
  });

  bool get leer => einnahmenCents == 0 && ausgabenCents == 0;

  factory Auswertung.fromJson(Map<String, dynamic> j) => Auswertung(
        von: DateTime.parse(j['von'].toString()),
        bis: DateTime.parse(j['bis'].toString()),
        einnahmenCents: (j['einnahmen_cents'] as num?)?.toInt() ?? 0,
        ausgabenCents: (j['ausgaben_cents'] as num?)?.toInt() ?? 0,
        saldoCents: (j['saldo_cents'] as num?)?.toInt() ?? 0,
        jeKategorie: [
          for (final e in (j['je_kategorie'] as List<dynamic>? ?? const []))
            Kategoriesumme.fromJson(e as Map<String, dynamic>),
        ],
      );
}

/// Ein Posten der Verteilung — immer positiv, siehe [Auswertung].
class Kategoriesumme {
  final int? kategorieId;
  final String name;
  final String color;
  final int cents;

  const Kategoriesumme({
    required this.name,
    required this.color,
    required this.cents,
    this.kategorieId,
  });

  factory Kategoriesumme.fromJson(Map<String, dynamic> j) => Kategoriesumme(
        kategorieId: (j['category_id'] as num?)?.toInt(),
        name: j['name']?.toString() ?? 'Ohne Kategorie',
        color: j['color']?.toString() ?? '#94A3B8',
        cents: (j['cents'] as num?)?.toInt() ?? 0,
      );
}

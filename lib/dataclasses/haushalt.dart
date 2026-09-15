/// Der Haushalt: mehrere Personen, die Teile der App gemeinsam benutzen.
///
/// **Haushalte sind additiv.** Sie stehen neben der persönlichen App,
/// nicht darüber. Wer in keinem ist, merkt vom ganzen Bereich nichts —
/// deshalb ist der Haushalt überall `Haushalt?` und nicht `Haushalt`, und
/// `null` ist der Normalfall und kein Fehler.
library;

/// Was die anderen von den Finanzen eines Mitglieds sehen dürfen.
///
/// Vier Stufen und nicht zwei: „nur Summen" ist nicht eindeutig. Eine
/// Verteilung nach Kategorie ist selbst schon halb ein Beleg — „Freizeit:
/// 400 €" verrät einiges.
enum Finanzsicht {
  nichts('nichts', 'Nichts', 'Die anderen sehen keine Zahl von dir.'),
  summe('summe', 'Nur die Summe',
      'Einnahmen, Ausgaben und Saldo des Zeitraums.'),
  kategorien('kategorien', 'Summe und Kategorien',
      'Zusätzlich, wofür das Geld ging.'),
  alles('alles', 'Alles', 'Auch die einzelnen Buchungen.');

  const Finanzsicht(this.schluessel, this.titel, this.erklaerung);

  /// Der Wert, wie er über die Leitung geht.
  final String schluessel;

  /// Was im Pop-up als Überschrift der Stufe steht.
  final String titel;

  /// Der Satz darunter. Ohne ihn müsste jeder raten, was „Kategorien"
  /// preisgibt — und das ist genau die Frage, bei der man sich nicht
  /// verschätzen möchte.
  final String erklaerung;

  /// Unbekannte Werte werden zu [nichts].
  ///
  /// Die vorsichtige Richtung: käme aus einem neueren Backend eine Stufe,
  /// die diese App nicht kennt, wäre alles andere ein Versprechen, das
  /// sie nicht halten kann.
  static Finanzsicht von(String? wert) => Finanzsicht.values.firstWhere(
        (s) => s.schluessel == wert,
        orElse: () => Finanzsicht.nichts,
      );
}

/// Ein Mitglied des Haushalts.
class Mitglied {
  final String userId;
  final String name;

  /// `besitzer` oder `mitglied`. Der Besitzer darf einladen, umbenennen
  /// und auflösen — er ist nicht Eigentümer der Daten.
  final String rolle;

  /// Was dieses Mitglied von sich preisgibt. Die Stufe selbst ist kein
  /// Geheimnis: die anderen sollen wissen, warum bei ihm keine Zahl
  /// steht. Die Zahlen dahinter sind es.
  final Finanzsicht finanzsicht;

  final DateTime? beigetreten;

  const Mitglied({
    required this.userId,
    required this.name,
    this.rolle = 'mitglied',
    this.finanzsicht = Finanzsicht.nichts,
    this.beigetreten,
  });

  bool get istBesitzer => rolle == 'besitzer';

  factory Mitglied.fromJson(Map<String, dynamic> j) => Mitglied(
        userId: j['user_id']?.toString() ?? '',
        name: j['name']?.toString() ?? '?',
        rolle: j['rolle']?.toString() ?? 'mitglied',
        finanzsicht: Finanzsicht.von(j['finanz_sicht']?.toString()),
        beigetreten: DateTime.tryParse(j['beigetreten_at']?.toString() ?? ''),
      );
}

/// Der Haushalt selbst.
class Haushalt {
  final int id;
  final String name;
  final String color;
  final String ownerId;
  final String ownerName;
  final List<Mitglied> mitglieder;
  final DateTime? angelegt;

  const Haushalt({
    required this.id,
    required this.name,
    this.color = '#0EA5E9',
    this.ownerId = '',
    this.ownerName = '',
    this.mitglieder = const [],
    this.angelegt,
  });

  bool gehoert(String userId) => ownerId == userId;

  /// Die eigene Zeile — oder null, wenn man gar nicht drin ist.
  Mitglied? mitglied(String userId) {
    for (final m in mitglieder) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  factory Haushalt.fromJson(Map<String, dynamic> j) => Haushalt(
        id: (j['id'] as num).toInt(),
        name: j['name']?.toString() ?? 'Haushalt',
        color: j['color']?.toString() ?? '#0EA5E9',
        ownerId: j['owner_id']?.toString() ?? '',
        ownerName: j['owner_name']?.toString() ?? '',
        mitglieder: [
          for (final m in (j['mitglieder'] as List<dynamic>? ?? const []))
            Mitglied.fromJson(m as Map<String, dynamic>),
        ],
        angelegt: DateTime.tryParse(j['created_at']?.toString() ?? ''),
      );
}

/// Eine Einladung — eine Frage, keine halbe Mitgliedschaft.
///
/// Vor dem Annehmen sieht keine Seite etwas von der anderen: der
/// Eingeladene kennt nur den Namen des Haushalts und den des Absenders.
class Einladung {
  final int id;
  final int haushaltId;
  final String haushaltName;
  final String userId;
  final String userName;
  final String vonId;
  final String vonName;
  final String zustand;
  final DateTime? angelegt;

  const Einladung({
    required this.id,
    required this.haushaltId,
    required this.haushaltName,
    required this.userId,
    required this.userName,
    required this.vonId,
    required this.vonName,
    this.zustand = 'offen',
    this.angelegt,
  });

  bool get istOffen => zustand == 'offen';

  factory Einladung.fromJson(Map<String, dynamic> j) => Einladung(
        id: (j['id'] as num).toInt(),
        haushaltId: (j['household_id'] as num).toInt(),
        haushaltName: j['household_name']?.toString() ?? 'Haushalt',
        userId: j['user_id']?.toString() ?? '',
        userName: j['user_name']?.toString() ?? '?',
        vonId: j['eingeladen_von']?.toString() ?? '',
        vonName: j['eingeladen_von_name']?.toString() ?? '?',
        zustand: j['zustand']?.toString() ?? 'offen',
        angelegt: DateTime.tryParse(j['created_at']?.toString() ?? ''),
      );
}


/// Was von einem Mitglied in der Haushaltsübersicht zu sehen ist.
///
/// **`null` heißt „gibt nichts preis" — nicht „hat null Euro".** Das ist
/// der Unterschied, den eine 0 verwischen würde, und der Grund, warum
/// die Felder hier nullbar sind.
class MitgliedsFinanzen {
  final String userId;
  final String name;

  /// Die Stufe selbst ist kein Geheimnis: die anderen sollen wissen,
  /// **warum** bei jemandem keine Zahl steht.
  final Finanzsicht finanzsicht;

  /// Ob dieses Mitglied in der Summe steckt.
  final bool rechnetMit;

  final int? einnahmenCents;
  final int? ausgabenCents;
  final int? saldoCents;

  const MitgliedsFinanzen({
    required this.userId,
    required this.name,
    this.finanzsicht = Finanzsicht.nichts,
    this.rechnetMit = false,
    this.einnahmenCents,
    this.ausgabenCents,
    this.saldoCents,
  });

  factory MitgliedsFinanzen.fromJson(Map<String, dynamic> j) =>
      MitgliedsFinanzen(
        userId: j['user_id']?.toString() ?? '',
        name: j['name']?.toString() ?? '?',
        finanzsicht: Finanzsicht.von(j['finanz_sicht']?.toString()),
        rechnetMit: j['rechnet_mit'] == true,
        einnahmenCents: (j['einnahmen_cents'] as num?)?.toInt(),
        ausgabenCents: (j['ausgaben_cents'] as num?)?.toInt(),
        saldoCents: (j['saldo_cents'] as num?)?.toInt(),
      );
}

/// Die zusammengerechneten Finanzen des Haushalts.
class HaushaltsFinanzen {
  final int haushaltId;
  final String name;
  final DateTime von;
  final DateTime bis;
  final int einnahmenCents;
  final int ausgabenCents;
  final int saldoCents;
  final List<MitgliedsFinanzen> mitglieder;

  /// Die zwei Zahlen, die verhindern, dass jemand eine unvollständige
  /// Summe für die Wahrheit hält: „2 von 3 Mitgliedern rechnen mit."
  final int rechnenMit;
  final int mitgliederGesamt;

  const HaushaltsFinanzen({
    required this.haushaltId,
    required this.name,
    required this.von,
    required this.bis,
    this.einnahmenCents = 0,
    this.ausgabenCents = 0,
    this.saldoCents = 0,
    this.mitglieder = const [],
    this.rechnenMit = 0,
    this.mitgliederGesamt = 0,
  });

  /// Fehlt jemand in der Summe?
  bool get unvollstaendig => rechnenMit < mitgliederGesamt;

  /// Wer nicht mitrechnet — für den Satz darunter.
  List<String> get fehlende => [
        for (final m in mitglieder)
          if (!m.rechnetMit) m.name,
      ];

  factory HaushaltsFinanzen.fromJson(Map<String, dynamic> j) =>
      HaushaltsFinanzen(
        haushaltId: (j['haushalt_id'] as num).toInt(),
        name: j['name']?.toString() ?? 'Haushalt',
        von: DateTime.parse(j['von'].toString()),
        bis: DateTime.parse(j['bis'].toString()),
        einnahmenCents: (j['einnahmen_cents'] as num?)?.toInt() ?? 0,
        ausgabenCents: (j['ausgaben_cents'] as num?)?.toInt() ?? 0,
        saldoCents: (j['saldo_cents'] as num?)?.toInt() ?? 0,
        mitglieder: [
          for (final m in (j['mitglieder'] as List<dynamic>? ?? const []))
            MitgliedsFinanzen.fromJson(m as Map<String, dynamic>),
        ],
        rechnenMit: (j['rechnen_mit'] as num?)?.toInt() ?? 0,
        mitgliederGesamt: (j['mitglieder_gesamt'] as num?)?.toInt() ?? 0,
      );
}

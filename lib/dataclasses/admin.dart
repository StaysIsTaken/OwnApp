/// Datenklassen für den Adminbereich: Rechte, Rollen, Benutzerübersicht.
library;

/// Ein Eintrag aus dem Rechte-Katalog. Der Katalog steht im Backend-Code,
/// nicht in der Datenbank — ein neu programmierter Bereich taucht hier also
/// von selbst auf, ohne dass in der App etwas nachgepflegt werden muss.
class Recht {
  final String key;
  final String bereich;
  final String beschreibung;

  const Recht({
    required this.key,
    required this.bereich,
    required this.beschreibung,
  });

  factory Recht.fromJson(Map<String, dynamic> j) => Recht(
        key: j['key'] as String,
        bereich: j['bereich'] as String? ?? 'Sonstiges',
        beschreibung: j['beschreibung'] as String? ?? '',
      );

  /// "lesen" / "schreiben" / … — der Teil hinter dem Doppelpunkt.
  String get aktion {
    final i = key.indexOf(':');
    return i < 0 ? key : key.substring(i + 1);
  }

  static const Map<String, String> _aktionsNamen = {
    'read': 'Sehen',
    'write': 'Ändern',
    'use': 'Benutzen',
    'configure': 'Einrichten',
    'users': 'Benutzer',
    'roles': 'Rollen',
    'system': 'System',
  };

  String get aktionLesbar => _aktionsNamen[aktion] ?? aktion;
}

class Rolle {
  final String id;
  final String key;
  final String name;
  final String? beschreibung;

  /// Systemrollen lassen sich nicht löschen — allen voran der Administrator.
  final bool istSystem;

  /// Die Rolle, die ein neu angelegter Nutzer bekommt. Höchstens eine.
  final bool istStandard;

  final List<String> rechte;
  final int nutzerAnzahl;

  const Rolle({
    required this.id,
    required this.key,
    required this.name,
    required this.istSystem,
    required this.istStandard,
    required this.rechte,
    required this.nutzerAnzahl,
    this.beschreibung,
  });

  factory Rolle.fromJson(Map<String, dynamic> j) => Rolle(
        id: j['id'] as String,
        key: j['key'] as String,
        name: j['name'] as String,
        beschreibung: j['description'] as String?,
        istSystem: j['is_system'] == true,
        istStandard: j['is_default'] == true,
        rechte: (j['permissions'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        nutzerAnzahl: (j['user_count'] as num?)?.toInt() ?? 0,
      );

  /// `*` schließt alles ein — dadurch deckt die Adminrolle auch Bereiche ab,
  /// die es beim Anlegen noch gar nicht gab.
  bool get darfAlles => rechte.contains('*');
}

class RolleKurz {
  final String id;
  final String key;
  final String name;

  const RolleKurz({required this.id, required this.key, required this.name});

  factory RolleKurz.fromJson(Map<String, dynamic> j) => RolleKurz(
        id: j['id'] as String? ?? '',
        key: j['key'] as String,
        name: j['name'] as String,
      );
}

class AdminBenutzer {
  final String id;
  final String username;
  final String vorname;
  final String nachname;
  final List<RolleKurz> rollen;
  final List<String> rechte;

  /// Deaktiviert = kommt nicht mehr herein, die Daten bleiben.
  final bool aktiv;

  /// Offene Benachrichtigungsverbindung im Moment der Abfrage.
  final bool online;

  /// Wie viele Verbindungen offen sind — Handy und Laptop zählen einzeln.
  final int verbindungen;

  /// Letzte Anfrage, auf die Minute genau nachgezogen.
  final DateTime? zuletztGesehen;

  const AdminBenutzer({
    required this.id,
    required this.username,
    required this.vorname,
    required this.nachname,
    required this.rollen,
    required this.rechte,
    required this.aktiv,
    required this.online,
    required this.verbindungen,
    this.zuletztGesehen,
  });

  factory AdminBenutzer.fromJson(Map<String, dynamic> j) => AdminBenutzer(
        id: j['id'] as String,
        username: j['username'] as String,
        vorname: j['first_name'] as String? ?? '',
        nachname: j['last_name'] as String? ?? '',
        rollen: (j['roles'] as List<dynamic>? ?? [])
            .map((e) => RolleKurz.fromJson(e as Map<String, dynamic>))
            .toList(),
        rechte: (j['permissions'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        aktiv: j['active'] != false,
        online: j['online'] == true,
        verbindungen: (j['connections'] as num?)?.toInt() ?? 0,
        zuletztGesehen: j['last_seen'] == null
            ? null
            : DateTime.tryParse(j['last_seen'] as String)?.toLocal(),
      );

  String get anzeigename {
    final voll = '$vorname $nachname'.trim();
    return voll.isEmpty ? username : voll;
  }
}

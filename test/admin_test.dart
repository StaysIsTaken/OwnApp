import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/admin.dart';

void main() {
  group('Rechte', () {
    test('der Stern schließt alles ein', () {
      final rolle = Rolle(
        id: '1', key: 'admin', name: 'Administrator',
        istSystem: true, istStandard: false,
        rechte: const ['*'], nutzerAnzahl: 1,
      );
      expect(rolle.darfAlles, isTrue);
    });

    test('Aktionen bekommen einen lesbaren Namen', () {
      const lesen = Recht(key: 'pantry:read', bereich: 'Vorrat', beschreibung: '');
      const einrichten =
          Recht(key: 'ai:configure', bereich: 'KI', beschreibung: '');
      expect(lesen.aktionLesbar, 'Sehen');
      expect(einrichten.aktionLesbar, 'Einrichten');
    });

    test('ein unbekanntes Recht wird trotzdem angezeigt', () {
      // Ein neu programmierter Bereich soll in der Oberfläche auftauchen,
      // auch wenn die App seine Aktion noch nicht kennt.
      const neu = Recht(key: 'garage:park', bereich: 'Garage', beschreibung: '');
      expect(neu.aktionLesbar, 'park');
    });
  });

  group('Benutzer aus dem Backend', () {
    Map<String, dynamic> json({
      bool online = false,
      int connections = 0,
      String? lastSeen,
      List<Map<String, dynamic>> roles = const [],
    }) => {
          'id': 'u1',
          'username': 'anna',
          'first_name': 'Anna',
          'last_name': 'Beispiel',
          'roles': roles,
          'permissions': ['pantry:read'],
          'online': online,
          'connections': connections,
          'last_seen': lastSeen,
        };

    test('Anzeigename bevorzugt den echten Namen', () {
      expect(AdminBenutzer.fromJson(json()).anzeigename, 'Anna Beispiel');
    });

    test('ohne Namen bleibt der Benutzername', () {
      final d = json()..['first_name'] = ''..['last_name'] = '';
      expect(AdminBenutzer.fromJson(d).anzeigename, 'anna');
    });

    test('mehrere Verbindungen zählen einzeln', () {
      final b = AdminBenutzer.fromJson(json(online: true, connections: 3));
      expect(b.online, isTrue);
      expect(b.verbindungen, 3);
    });

    test('fehlendes last_seen ist kein Fehler', () {
      expect(AdminBenutzer.fromJson(json()).zuletztGesehen, isNull);
    });

    test('ohne Angabe gilt ein Konto als aktiv', () {
      // Ein altes Backend ohne dieses Feld darf nicht dazu fuehren, dass
      // ploetzlich jeder als gesperrt angezeigt wird.
      expect(AdminBenutzer.fromJson(json()).aktiv, isTrue);
    });

    test('deaktiviert kommt durch', () {
      final d = json()..['active'] = false;
      expect(AdminBenutzer.fromJson(d).aktiv, isFalse);
    });

    test('Rollen kommen mit', () {
      final b = AdminBenutzer.fromJson(json(roles: [
        {'id': 'r1', 'key': 'haushalt', 'name': 'Haushalt'},
      ]));
      expect(b.rollen.single.name, 'Haushalt');
    });
  });
}

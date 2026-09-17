import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/haushalt.dart';
import 'package:productivity/dataservice/haushalt_sicht.dart';

/// Die Sichtbarkeitsregel der Haushalte — als reine Rechnung prüfbar.
///
/// Derselbe Kunstgriff wie bei `finanz_rechnung.dart`: die Seiten laden
/// beim Aufbau und sind damit nicht prüfbar, die Regel dahinter schon.
/// Und diese Regel ist es wert — an ihr hängt das Leitprinzip.
void main() {
  _freigabe();

  const alice = Mitglied(userId: 'u1', name: 'Alice', rolle: 'besitzer');
  const bob = Mitglied(userId: 'u2', name: 'Bob');

  const allein = Haushalt(
    id: 1, name: 'Zuhause', ownerId: 'u1', mitglieder: [alice]);
  const zuZweit = Haushalt(
    id: 1, name: 'Zuhause', ownerId: 'u1', mitglieder: [alice, bob]);

  const einladung = Einladung(
    id: 7,
    haushaltId: 1,
    haushaltName: 'Zuhause',
    userId: 'u2',
    userName: 'Bob',
    vonId: 'u1',
    vonName: 'Alice',
  );

  group('Das Menü', () {
    test('ohne Haushalt und ohne Einladung gibt es nichts', () {
      expect(Haushaltssicht.zeigtMenue(), isFalse);
    });

    test('im Haushalt gibt es etwas', () {
      expect(Haushaltssicht.zeigtMenue(haushalt: zuZweit), isTrue);
    });

    test('eine offene Einladung reicht schon', () {
      // Sonst käme sie nirgends an: es gäbe keinen Ort, sie zu
      // beantworten.
      expect(Haushaltssicht.zeigtMenue(offeneEinladungen: 1), isTrue);
    });
  });

  group('Die Umschaltung „Meins / Unseres"', () {
    test('verschwindet vollständig ohne Haushalt', () {
      // Das ist die Stelle, an der das Leitprinzip kaputtgeht, wenn
      // jemand sie vergisst.
      expect(Haushaltssicht.zeigtUmschaltung(null), isFalse);
    });

    test('erscheint im Haushalt', () {
      expect(Haushaltssicht.zeigtUmschaltung(allein), isTrue);
    });
  });

  group('Gehen', () {
    test('ein Mitglied darf jederzeit', () {
      expect(Haushaltssicht.darfGehen(zuZweit, 'u2'), isTrue);
    });

    test('der Besitzer nicht, solange andere drin sind', () {
      // Der Fall, den man vergisst: ein Haushalt ohne Besitzer hätte
      // niemanden, der einladen oder auflösen darf.
      expect(Haushaltssicht.darfGehen(zuZweit, 'u1'), isFalse);
    });

    test('der Besitzer schon, wenn er allein ist', () {
      expect(Haushaltssicht.darfGehen(allein, 'u1'), isTrue);
    });
  });

  group('Die Finanz-Sichtbarkeit', () {
    test('die Vorgabe ist nichts', () {
      // Die Zeile, die man leicht falsch herum baut.
      expect(const Mitglied(userId: 'u1', name: 'A').finanzsicht,
          Finanzsicht.nichts);
    });

    test('jede Stufe kommt über die Leitung und zurück', () {
      for (final stufe in Finanzsicht.values) {
        expect(Finanzsicht.von(stufe.schluessel), stufe);
      }
    });

    test('eine unbekannte Stufe wird zu nichts', () {
      // Die vorsichtige Richtung: käme aus einem neueren Backend eine
      // Stufe, die diese App nicht kennt, wäre alles andere ein
      // Versprechen, das sie nicht halten kann.
      expect(Finanzsicht.von('alles_und_mehr'), Finanzsicht.nichts);
      expect(Finanzsicht.von(null), Finanzsicht.nichts);
    });

    test('jede Stufe erklärt sich selbst', () {
      // Ohne den Satz müsste jeder raten, was „Kategorien" preisgibt.
      for (final stufe in Finanzsicht.values) {
        expect(stufe.titel, isNotEmpty);
        expect(stufe.erklaerung, isNotEmpty);
      }
    });
  });

  group('Der Mitgliedersatz', () {
    test('allein', () {
      expect(Haushaltssicht.mitgliederSatz(allein), 'Nur du');
    });

    test('zu zweit', () {
      expect(Haushaltssicht.mitgliederSatz(zuZweit), '2 Mitglieder');
    });
  });

  group('Was aus dem Backend kommt', () {
    test('ein Haushalt samt Mitgliedern', () {
      final h = Haushalt.fromJson(const {
        'id': 3,
        'name': 'Zuhause',
        'color': '#0EA5E9',
        'owner_id': 'u1',
        'owner_name': 'Alice',
        'mitglieder': [
          {
            'user_id': 'u1',
            'name': 'Alice',
            'rolle': 'besitzer',
            'finanz_sicht': 'summe',
          },
          {'user_id': 'u2', 'name': 'Bob', 'rolle': 'mitglied'},
        ],
      });

      expect(h.id, 3);
      expect(h.gehoert('u1'), isTrue);
      expect(h.gehoert('u2'), isFalse);
      expect(h.mitglied('u1')?.finanzsicht, Finanzsicht.summe);
      // Fehlt das Feld, gilt die vorsichtige Vorgabe.
      expect(h.mitglied('u2')?.finanzsicht, Finanzsicht.nichts);
      expect(h.mitglied('u3'), isNull);
    });

    test('eine Einladung', () {
      final e = Einladung.fromJson(const {
        'id': 7,
        'household_id': 1,
        'household_name': 'Zuhause',
        'user_id': 'u2',
        'user_name': 'Bob',
        'eingeladen_von': 'u1',
        'eingeladen_von_name': 'Alice',
        'zustand': 'offen',
      });

      expect(e.istOffen, isTrue);
      expect(e.haushaltName, 'Zuhause');
      expect(e.vonName, 'Alice');
    });

    test('eine beantwortete Einladung ist nicht mehr offen', () {
      expect(einladung.istOffen, isTrue);
      final abgelehnt = Einladung.fromJson(const {
        'id': 7,
        'household_id': 1,
        'household_name': 'Zuhause',
        'user_id': 'u2',
        'user_name': 'Bob',
        'eingeladen_von': 'u1',
        'eingeladen_von_name': 'Alice',
        'zustand': 'abgelehnt',
      });
      expect(abgelehnt.istOffen, isFalse);
    });
  });
}

/// Die MCP-Freigabe: wer gibt frei, und was sagt die Seite darüber.
///
/// Derselbe Gedanke wie bei „2 von 3 rechnen mit": was ein Assistent aus
/// dem Haushalt bekommt, ist unvollständig, sobald jemand nicht
/// freigibt. Das gehört dazugesagt — sonst hält jemand eine halbe Liste
/// für die ganze.
void _freigabe() {
  Mitglied wer(String name, {bool frei = false}) =>
      Mitglied(userId: name, name: name, mcpFreigabe: frei);

  group('Freigabe-Satz', () {
    test('alle geben frei', () {
      final satz = Haushaltssicht.freigabeSatz(
          [wer('Anna', frei: true), wer('Bert', frei: true)]);

      expect(satz, 'Alle geben ihre Beiträge frei.');
    });

    test('niemand gibt frei', () {
      final satz = Haushaltssicht.freigabeSatz([wer('Anna'), wer('Bert')]);

      expect(satz, contains('Niemand'));
      expect(satz, contains('geht nichts heraus'));
    });

    test('einer fehlt und wird genannt', () {
      final satz = Haushaltssicht.freigabeSatz(
          [wer('Anna', frei: true), wer('Bert')]);

      expect(satz, contains('1 von 2'));
      expect(satz, contains('Bert gibt nicht frei'));
    });

    test('mehrere fehlen und werden alle genannt', () {
      final satz = Haushaltssicht.freigabeSatz(
          [wer('Anna', frei: true), wer('Bert'), wer('Cem')]);

      expect(satz, contains('1 von 3'));
      expect(satz, contains('Bert, Cem geben nicht frei'));
    });

    test('ohne Mitglieder gibt es nichts zu sagen', () {
      expect(Haushaltssicht.freigabeSatz([]), isEmpty);
    });
  });

  group('Vorgabe', () {
    test('ein frisches Mitglied gibt nichts frei', () {
      // Eine Mitgliedschaft ist kein Einverständnis — dieselbe Zeile
      // wie bei der Finanz-Sichtbarkeit.
      expect(const Mitglied(userId: 'x', name: 'X').mcpFreigabe, isFalse);
    });

    test('das Feld kommt aus der Antwort des Servers', () {
      final m = Mitglied.fromJson(
          {'user_id': 'x', 'name': 'X', 'mcp_freigabe': true});

      expect(m.mcpFreigabe, isTrue);
    });

    test('fehlt es in der Antwort, gilt nein', () {
      // Ein altes Backend ohne dieses Feld darf nicht versehentlich
      // freigeben.
      final m = Mitglied.fromJson({'user_id': 'x', 'name': 'X'});

      expect(m.mcpFreigabe, isFalse);
    });
  });

  group('2 von 3 deiner Kalender laufen mit', () {
    // Dritter Satz neben mitrechnenSatz und freigabeSatz, und aus
    // demselben Grund: eine Vorgabe, die „nein" heisst, muss man sehen
    // koennen -- sonst haelt man sie fuer „noch nicht eingerichtet".
    test('ohne eigene Kalender gibt es nichts zu sagen', () {
      expect(Haushaltssicht.kalenderSatz(frei: 0, gesamt: 0), '');
    });

    test('keiner freigegeben: es steht da, und es steht da, was zu tun ist',
        () {
      final satz = Haushaltssicht.kalenderSatz(frei: 0, gesamt: 3);
      expect(satz, contains('keinen deiner Kalender'));
      expect(satz, contains('Leg um'));
    });

    test('alle freigegeben wird auch gesagt', () {
      // Anders als bei mitrechnenSatz: dort ist Vollstaendigkeit der
      // Normalfall und schweigt. Hier ist es eine Preisgabe, und die
      // moechte man nachlesen koennen, ohne Schalter fuer Schalter zu
      // gehen.
      expect(Haushaltssicht.kalenderSatz(frei: 3, gesamt: 3),
          'Alle deine Kalender laufen im Haushalt mit.');
    });

    test('bei genau einem steht die Einzahl da', () {
      expect(Haushaltssicht.kalenderSatz(frei: 1, gesamt: 1),
          'Dein Kalender läuft im Haushalt mit.');
    });

    test('teilweise: die Zahlen stehen da', () {
      expect(Haushaltssicht.kalenderSatz(frei: 2, gesamt: 3),
          '2 von 3 deiner Kalender laufen im Haushalt mit.');
    });
  });
}

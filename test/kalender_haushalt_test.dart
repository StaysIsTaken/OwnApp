// Kalender im Haushalt: zwei Wege, und die App muss sie auseinanderhalten.
//
// Vorher gab es genau eine Art, einen fremden Kalender zu sehen: die
// Einzelfreigabe (`kalender_freigabe_test.dart`). Dazu kommen zwei Dinge,
// die sich aehnlich anfuehlen und verschieden sind:
//
// * `haushaltsFreigabe` -- MEIN Kalender, aber ihr duerft mitlesen.
// * `istHaushaltskalender` -- UNSER Kalender, er gehoert niemandem.
//
// Der Fehler, den diese Datei verhindert, ist immer derselbe: die App
// rechnet `ownerId == meineId`, um zu wissen, was sie darf. Beim
// gemeinsamen Kalender steht dort NIEMAND -- er saehe damit fremd aus und
// waere zugesperrt, obwohl jedes Mitglied ihn pflegen darf. Deshalb kommen
// `may_write` und `may_manage` vom Server, und deshalb gibt es [gehoert]
// getrennt von [darfVerwalten].
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/kalender.dart';

void main() {
  group('Was vom Server ankommt', () {
    test('der gemeinsame Kalender hat keinen Besitzer', () {
      final k = Kalender.fromJson({
        'id': 9,
        'owner_id': null,
        'owner_name': 'Zuhause',
        'name': 'Familie',
        'color': '#0EA5E9',
        'is_default': false,
        'household_id': 2,
        'is_household': true,
        'may_write': true,
        'may_manage': true,
        'entry_count': 5,
      });
      expect(k.ownerId, isNull);
      expect(k.istHaushaltskalender, isTrue);
      expect(k.haushaltId, 2);
      // Wo sonst die Person steht, steht der Haushalt -- sonst hiessen im
      // Haushalt mehrere Kalender gleich und nichts unterschiede sie.
      expect(k.ownerName, 'Zuhause');
    });

    test('der Schalter am eigenen Kalender kommt mit', () {
      final k = Kalender.fromJson({
        'id': 1, 'owner_id': 'u1', 'owner_name': 'Jan', 'name': 'Arbeit',
        'household_share': true, 'may_write': true, 'may_manage': true,
      });
      expect(k.haushaltsFreigabe, isTrue);
      expect(k.istHaushaltskalender, isFalse);
    });

    test('ein aelterer Server nimmt nichts weg und gibt nichts dazu', () {
      // Die vorsichtige Richtung: fehlen die Felder, ist die Antwort nein.
      // Alles andere waere ein Versprechen, das die App nicht halten kann
      // -- derselbe Gedanke wie bei Finanzsicht.von.
      final k = Kalender.fromJson({'id': 3, 'name': 'Privat'});
      expect(k.haushaltsFreigabe, isFalse);
      expect(k.istHaushaltskalender, isFalse);
      expect(k.darfSchreiben, isFalse);
      expect(k.darfVerwalten, isFalse);
    });
  });

  group('Gehoert er mir?', () {
    Kalender gemeinsam() => const Kalender(
          id: 9, ownerId: null, ownerName: 'Zuhause', name: 'Familie',
          color: '#0EA5E9', istHaushaltskalender: true, haushaltId: 2,
          darfSchreiben: true, darfVerwalten: true,
        );

    Kalender meiner() => const Kalender(
          id: 1, ownerId: 'u1', ownerName: 'Jan', name: 'Privat',
          color: '#3B82F6', darfSchreiben: true, darfVerwalten: true,
        );

    Kalender fremder() => const Kalender(
          id: 2, ownerId: 'u2', ownerName: 'Lisa', name: 'Privat',
          color: '#EF4444',
        );

    test('meiner gehoert mir', () {
      expect(meiner().gehoert('u1'), isTrue);
    });

    test('der gemeinsame gehoert niemandem -- auch mir nicht', () {
      // DER Test dieser Datei. Er darf trotzdem alles: gehoeren und
      // duerfen sind hier zwei verschiedene Fragen.
      expect(gemeinsam().gehoert('u1'), isFalse);
      expect(gemeinsam().darfVerwalten, isTrue);
      expect(gemeinsam().darfSchreiben, isTrue);
    });

    test('ein fremder gehoert mir nicht und darf nichts', () {
      expect(fremder().gehoert('u1'), isFalse);
      expect(fremder().darfSchreiben, isFalse);
    });

    test('ohne angemeldeten Nutzer gehoert mir nichts', () {
      // `null` kommt vor: die Verwaltungsseite liest die eigene Kennung
      // aus dem Provider, und der kann beim ersten Aufbau leer sein.
      expect(meiner().gehoert(null), isFalse);
      expect(gemeinsam().gehoert(null), isFalse);
    });
  });

  group('Wohin darf der Import?', () {
    // Die Liste im Import-Fenster zeigt, wohin man schreiben darf. Ein
    // fremder freigegebener Kalender steht nicht dabei: eine Freigabe
    // oeffnet ihn zum Lesen. Stuende er da, liefe der Import in ein 403 --
    // nachdem der Nutzer die Datei gewaehlt hat.
    final kalender = <Kalender>[
      const Kalender(
          id: 1, ownerId: 'u1', ownerName: 'Jan', name: 'Mein Kalender',
          color: '#3B82F6', istStandard: true,
          darfSchreiben: true, darfVerwalten: true),
      const Kalender(
          id: 2, ownerId: 'u2', ownerName: 'Lisa', name: 'Lisas Arbeit',
          color: '#EF4444', haushaltsFreigabe: true),
      const Kalender(
          id: 9, ownerId: null, ownerName: 'Zuhause', name: 'Familie',
          color: '#0EA5E9', istHaushaltskalender: true, haushaltId: 2,
          darfSchreiben: true, darfVerwalten: true),
    ];

    test('nur beschreibbare Kalender stehen zur Wahl', () {
      final ziele = kalender.where((k) => k.darfSchreiben).map((k) => k.id);
      expect(ziele, [1, 9]);
    });

    test('mitlesen duerfen heisst nicht hineinschreiben duerfen', () {
      final lisas = kalender.firstWhere((k) => k.id == 2);
      expect(lisas.haushaltsFreigabe, isTrue);
      expect(lisas.darfSchreiben, isFalse);
    });
  });
}

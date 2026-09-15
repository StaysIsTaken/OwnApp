import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/haushalt.dart';
import 'package:productivity/dataservice/haushalt_sicht.dart';

/// Der Satz unter der Summe — „2 von 3 Mitgliedern rechnen mit."
///
/// **Ohne ihn hält jemand eine unvollständige Summe für die Wahrheit.**
/// Derselbe Gedanke wie bei `ohne_preis` und `ohne_zutat`: lieber
/// ehrlich sagen, was nicht verrechnet werden konnte, als eine Zahl
/// zeigen, die vollständig aussieht.
void main() {
  HaushaltsFinanzen finanzen(List<MitgliedsFinanzen> mitglieder) =>
      HaushaltsFinanzen(
        haushaltId: 1,
        name: 'Zuhause',
        von: DateTime(2026, 9, 1),
        bis: DateTime(2026, 9, 30),
        ausgabenCents: 12000,
        mitglieder: mitglieder,
        rechnenMit: mitglieder.where((m) => m.rechnetMit).length,
        mitgliederGesamt: mitglieder.length,
      );

  const alice = MitgliedsFinanzen(
    userId: 'u1',
    name: 'Alice',
    finanzsicht: Finanzsicht.summe,
    rechnetMit: true,
    saldoCents: -5000,
  );
  const bob = MitgliedsFinanzen(userId: 'u2', name: 'Bob');
  const carl = MitgliedsFinanzen(userId: 'u3', name: 'Carl');

  group('Der Satz', () {
    test('rechnen alle mit, steht da nichts', () {
      // Eine Beruhigung („alle rechnen mit") wäre eine Zeile, die man
      // nach dem dritten Mal nicht mehr liest — und dann übersieht man
      // auch die Warnung.
      final f = finanzen([alice]);
      expect(f.unvollstaendig, isFalse);
      expect(Haushaltssicht.mitrechnenSatz(f), isEmpty);
    });

    test('fehlt einer, steht er mit Namen da', () {
      final f = finanzen([alice, bob]);
      final satz = Haushaltssicht.mitrechnenSatz(f);

      expect(satz, contains('1 von 2'));
      expect(satz, contains('Bob'));
      expect(satz, contains('zeigt seine Zahlen nicht'));
    });

    test('fehlen mehrere, stehen alle da', () {
      final f = finanzen([alice, bob, carl]);
      final satz = Haushaltssicht.mitrechnenSatz(f);

      expect(satz, contains('1 von 3'));
      expect(satz, contains('Bob'));
      expect(satz, contains('Carl'));
      expect(satz, contains('zeigen ihre Zahlen nicht'));
    });

    test('wer fehlt, steht auch einzeln zur Verfügung', () {
      expect(finanzen([alice, bob, carl]).fehlende, ['Bob', 'Carl']);
    });
  });

  group('Was aus dem Backend kommt', () {
    test('null heißt „gibt nichts preis", nicht „null Euro"', () {
      // Der Unterschied, den eine 0 verwischen würde.
      final m = MitgliedsFinanzen.fromJson(const {
        'user_id': 'u2',
        'name': 'Bob',
        'finanz_sicht': 'nichts',
        'rechnet_mit': false,
      });

      expect(m.rechnetMit, isFalse);
      expect(m.saldoCents, isNull);
      expect(m.ausgabenCents, isNull);
    });

    test('eine Stufe mit Zahlen kommt vollständig an', () {
      final m = MitgliedsFinanzen.fromJson(const {
        'user_id': 'u1',
        'name': 'Alice',
        'finanz_sicht': 'summe',
        'rechnet_mit': true,
        'einnahmen_cents': 250000,
        'ausgaben_cents': 120000,
        'saldo_cents': 130000,
      });

      expect(m.finanzsicht, Finanzsicht.summe);
      expect(m.saldoCents, 130000);
    });

    test('die ganze Übersicht', () {
      final f = HaushaltsFinanzen.fromJson(const {
        'haushalt_id': 1,
        'name': 'Zuhause',
        'von': '2026-09-01',
        'bis': '2026-09-30',
        'einnahmen_cents': 250000,
        'ausgaben_cents': 120000,
        'saldo_cents': 130000,
        'rechnen_mit': 1,
        'mitglieder_gesamt': 2,
        'mitglieder': [
          {
            'user_id': 'u1',
            'name': 'Alice',
            'finanz_sicht': 'alles',
            'rechnet_mit': true,
            'saldo_cents': 130000,
          },
          {
            'user_id': 'u2',
            'name': 'Bob',
            'finanz_sicht': 'nichts',
            'rechnet_mit': false,
          },
        ],
      });

      expect(f.unvollstaendig, isTrue);
      expect(f.fehlende, ['Bob']);
      expect(Haushaltssicht.mitrechnenSatz(f), contains('1 von 2'));
    });

    test('eine unbekannte Stufe wird zu nichts', () {
      // Die vorsichtige Richtung, wie überall: käme aus einem neueren
      // Backend eine Stufe, die diese App nicht kennt, wäre alles andere
      // ein Versprechen, das sie nicht halten kann.
      final m = MitgliedsFinanzen.fromJson(const {
        'user_id': 'u9',
        'name': 'Neu',
        'finanz_sicht': 'alles_und_mehr',
      });
      expect(m.finanzsicht, Finanzsicht.nichts);
    });
  });
}

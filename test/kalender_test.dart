// Kalender als eigene Objekte in der App: was aus dem Backend ankommt und
// welches Recht die Verwaltungsseite verlangt.
//
// Der Anlass war handfest: der Dienst war da, aber keine Oberflaeche rief
// ihn auf – anlegen konnte man keinen Kalender. Die Zuordnung Route → Recht
// ist der Teil davon, der sich ohne Widgets pruefen laesst.
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/kalender.dart';
import 'package:productivity/dataservice/rechte_zuordnung.dart';
import 'package:productivity/main.dart';

void main() {
  group('Was vom Server ankommt', () {
    test('ein vollstaendiger Kalender wird gelesen', () {
      final k = Kalender.fromJson({
        'id': 4,
        'owner_id': 'u1',
        'owner_name': 'Jan',
        'name': 'Müllabfuhr',
        'color': '#22C55E',
        'is_default': false,
        'ics_url': 'https://example.org/abfuhr.ics',
        'ics_synced_at': '2026-09-05T08:00:00',
        'entry_count': 12,
      });
      expect(k.name, 'Müllabfuhr');
      expect(k.anzahlTermine, 12);
      expect(k.zuletztGeholt, isNotNull);
    });

    test('ein abonnierter Kalender ist an der Adresse erkennbar', () {
      // Danach entscheidet die Oberflaeche, ob sie den Knopf "jetzt holen"
      // zeigt – ein selbst gepflegter Kalender hat nichts zu holen.
      final abo = Kalender.fromJson({
        'id': 1, 'name': 'Feiertage', 'ics_url': 'https://example.org/f.ics',
      });
      expect(abo.istAbonniert, isTrue);
    });

    test('ohne Adresse ist er selbst gepflegt', () {
      final eigen = Kalender.fromJson({'id': 2, 'name': 'Privat'});
      expect(eigen.istAbonniert, isFalse);
    });

    test('eine leere Adresse zaehlt nicht als Abo', () {
      // Der Server liefert je nach Zustand null oder "" – beides heisst
      // dasselbe, und sonst stuende ein toter Knopf da.
      final k = Kalender.fromJson({'id': 3, 'name': 'X', 'ics_url': ''});
      expect(k.istAbonniert, isFalse);
    });

    test('fehlende Felder ergeben brauchbare Vorgaben statt eines Fehlers', () {
      final k = Kalender.fromJson({'id': 9});
      expect(k.name, isNotEmpty);
      expect(k.color, startsWith('#'));
      expect(k.anzahlTermine, 0);
    });

    test('der Standardkalender ist als solcher erkennbar', () {
      // Er laesst sich nicht loeschen – jeder braucht einen, in dem Termine
      // ohne eigene Angabe landen.
      final k = Kalender.fromJson({'id': 1, 'name': 'Privat', 'is_default': true});
      expect(k.istStandard, isTrue);
    });
  });

  group('Erreichbarkeit', () {
    test('die Verwaltungsseite hat eine Route', () {
      expect(AppRoutes.routes.containsKey(AppRoutes.kalender), isTrue);
    });

    test('sie verlangt planner:read', () {
      // Ohne Eintrag gaelte sie als frei zugaenglich und stuende im Menue
      // auch fuer Rollen, die nichts damit anfangen koennen.
      expect(rechtJeRoute[AppRoutes.kalender], 'planner:read');
    });
  });
}

// Die Befehlserkennung des Kuechenassistenten: was das Tablet selbst
// beantwortet, bevor irgendetwas an den Server geht.
//
// Reine Zeichenkettenarbeit, also ohne Widget und ohne Netz pruefbar. Die
// Beispiele sind so formuliert, wie Whisper sie liefert -- gross geschrieben,
// mit Satzzeichen, mit Fuellwoertern.
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/dashboard_page.dart';
import 'package:productivity/dataservice/sprachbefehle.dart';
import 'package:productivity/provider/tablet_seiten_provider.dart';

DashboardSeite seite(int id, String name) => DashboardSeite(
      id: id,
      key: 'k$id',
      name: name,
      mode: DashboardSeite.modeTablet,
      orderIndex: id,
    );

void main() {
  group('Navigationsziel', () {
    test('einfache Einleitungen liefern das Ziel', () {
      expect(Sprachbefehle.navigationsZiel('Geh zum Kalender'), 'kalender');
      expect(Sprachbefehle.navigationsZiel('Zeig mir die Einkaufsliste'),
          'einkaufsliste');
      expect(Sprachbefehle.navigationsZiel('Öffne den Wochenplan'),
          'wochenplan');
    });

    test('Fuellwoerter und Endungen fallen weg', () {
      expect(Sprachbefehle.navigationsZiel('Geh in die Kalenderansicht'),
          'kalender');
      expect(Sprachbefehle.navigationsZiel('Wechsle zur Vorratsseite'),
          'vorrats');
    });

    test('mehrere Fuellwoerter hintereinander fallen alle weg', () {
      expect(Sprachbefehle.navigationsZiel('Geh zurück zu Kalender'),
          'kalender');
      expect(Sprachbefehle.navigationsZiel('Geh wieder zurück zur Übersicht'),
          'übersicht');
    });

    test('das laengere Verb gewinnt', () {
      // Sonst laese sich "gehe" als "geh" plus Rest "e".
      expect(Sprachbefehle.navigationsZiel('Gehe zum Kalender'), 'kalender');
    });

    test('die Anrede stoert nicht, falls sie mit aufgenommen wurde', () {
      expect(Sprachbefehle.navigationsZiel('Jarvis, zeig mir den Kalender'),
          'kalender');
    });

    test('ohne Einleitung ist es kein Navigationsbefehl', () {
      // Das Wichtigste an der ganzen Erkennung: sonst wuerde daraus ein
      // Ansichtswechsel statt eines Termins.
      expect(Sprachbefehle.navigationsZiel('Kalender morgen um drei eintragen'),
          isNull);
      expect(Sprachbefehle.navigationsZiel('Milch auf die Einkaufsliste'),
          isNull);
      expect(Sprachbefehle.navigationsZiel(''), isNull);
    });
  });

  group('Seitensuche', () {
    late TabletSeitenProvider provider;

    setUp(() {
      provider = TabletSeitenProvider();
      provider.setzeSeitenFuerTest([
        seite(1, 'Übersicht'),
        seite(2, 'Kalender'),
        seite(3, 'Einkauf'),
        seite(4, 'Einkaufsliste'),
      ]);
    });

    test('findet die genannte Seite und wechselt hin', () {
      expect(provider.wechsleNach('kalender'), 'Kalender');
      expect(provider.aktuell, 1);
    });

    test('Satzzeichen und Grossschreibung stoeren nicht', () {
      expect(provider.wechsleNach('Übersicht.'), 'Übersicht');
      expect(provider.aktuell, 0);
    });

    test('bei mehreren Treffern gewinnt der laengste Name', () {
      // "Einkauf" steckt in "Einkaufsliste" -- gemeint ist die Liste.
      expect(provider.wechsleNach('einkaufsliste'), 'Einkaufsliste');
      expect(provider.aktuell, 3);
    });

    test('unbekannte Seite aendert nichts', () {
      provider.wechsleZu(2);
      expect(provider.wechsleNach('wetterbericht'), isNull);
      expect(provider.aktuell, 2);
    });
  });
}

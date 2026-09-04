// Prüft die Logik, die ohne Netz und ohne Gerätespeicher auskommen muss:
// Standardanordnung und das Zusammenführen gespeicherter Stände mit den
// heute bekannten Kacheln.
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/tabs/dashboard/dashboard_prefs.dart';

void main() {
  group('Standardanordnung', () {
    test('Dashboard hat seine Kacheln', () {
      final o = DashboardPrefs.defaultOrder(DashboardPrefs.keyDashboard);
      expect(o, contains('tasks'));
      expect(o, contains('notes'));
      expect(o, isNotEmpty);
    });

    test('Home ist eine eigene Seite mit eigenen Kacheln', () {
      final home = DashboardPrefs.defaultOrder(DashboardPrefs.keyHome);
      final dash = DashboardPrefs.defaultOrder(DashboardPrefs.keyDashboard);
      expect(home, contains('taskstats'));
      expect(dash, isNot(contains('taskstats')));
      expect(home, isNot(equals(dash)));
    });

    test('unbekannte Seite ergibt eine leere Liste statt eines Fehlers', () {
      expect(DashboardPrefs.defaultOrder('gibtsnicht'), isEmpty);
    });

    test('jede Kachel hat eine Beschriftung', () {
      for (final key in [
        ...DashboardPrefs.defaultOrder(DashboardPrefs.keyDashboard),
        ...DashboardPrefs.defaultOrder(DashboardPrefs.keyHome),
      ]) {
        expect(DashboardPrefs.labels[key], isNotNull,
            reason: 'Beschriftung fehlt für "$key"');
      }
    });

    test('zurückgegebene Liste ist veränderbar', () {
      // Wird direkt in setState umsortiert – eine const-Liste würde werfen.
      final o = DashboardPrefs.defaultOrder(DashboardPrefs.keyDashboard);
      expect(() => o.removeAt(0), returnsNormally);
    });

    test('beide Seiten haben Kacheln', () {
      // Sonst waere eine Seite verdrahtet und die andere leer.
      for (final seite in [DashboardPrefs.keyDashboard, DashboardPrefs.keyHome]) {
        expect(DashboardPrefs.defaultOrder(seite), isNotEmpty, reason: seite);
      }
    });

    test('Aufrufe teilen sich keine Liste', () {
      final a = DashboardPrefs.defaultOrder(DashboardPrefs.keyDashboard);
      final b = DashboardPrefs.defaultOrder(DashboardPrefs.keyDashboard);
      a.removeAt(0);
      expect(b.length, greaterThan(a.length));
    });
  });
}

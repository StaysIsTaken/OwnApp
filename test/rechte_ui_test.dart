import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/dashboard_page.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/dataservice/rechte_zuordnung.dart';
import 'package:productivity/provider/permission_provider.dart';

DioException _fehler(int? status, {dynamic data}) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: status == null
          ? null
          : Response(
              requestOptions: RequestOptions(path: '/x'),
              statusCode: status,
              data: data,
            ),
    );

void main() {
  _kuechenmodus();

  group('Fehler vom Server', () {
    test('403 ist verboten, 401 nicht', () {
      // 401 heisst "nicht angemeldet" und fuehrt woanders zum Abmelden —
      // die beiden duerfen nicht verwechselt werden.
      expect(ApiFehler.istVerboten(_fehler(403)), isTrue);
      expect(ApiFehler.istVerboten(_fehler(401)), isFalse);
    });

    test('die Begründung des Servers kommt durch', () {
      final e = _fehler(403, data: {'detail': 'Dafür fehlt dir pantry:write.'});
      expect(ApiFehler.text(e), 'Dafür fehlt dir pantry:write.');
    });

    test('ohne Begründung gibt es einen verständlichen Ersatz', () {
      expect(ApiFehler.text(_fehler(403)), contains('Berechtigung'));
    });

    test('ohne Antwort ist es ein Netzproblem, kein Rechteproblem', () {
      final e = _fehler(null);
      expect(ApiFehler.istNetzproblem(e), isTrue);
      expect(ApiFehler.istVerboten(e), isFalse);
      expect(ApiFehler.text(e), contains('nicht erreichbar'));
    });
  });

  group('Eigene Rechte', () {
    test('der Stern schließt alles ein', () {
      final p = PermissionProvider();
      p.uebernehmen({'*'});
      expect(p.darf('pantry:read'), isTrue);
      expect(p.darf('was:auch:immer'), isTrue);
      expect(p.istGesperrt, isFalse);
    });

    test('ohne das passende Recht ist es aus', () {
      final p = PermissionProvider();
      p.uebernehmen({'pantry:read'});
      expect(p.darf('pantry:read'), isTrue);
      expect(p.darf('pantry:write'), isFalse);
    });

    test('gar kein Recht heißt gesperrt', () {
      final p = PermissionProvider();
      p.uebernehmen({});
      expect(p.istGesperrt, isTrue);
    });

    test('vor dem Laden gilt niemand als gesperrt', () {
      // Sonst würde beim Start kurz die "noch nicht freigeschaltet"-Seite
      // aufblitzen, bevor die Rechte da sind.
      expect(PermissionProvider().istGesperrt, isFalse);
    });

    test('Verwaltung schon bei einem der beiden Rechte', () {
      final p = PermissionProvider();
      p.uebernehmen({'admin:users'});
      expect(p.darfVerwalten, isTrue);
    });
  });

  group('Zuordnung Bereich → Recht', () {
    test('jede Kachel kennt ihre Datenquelle', () {
      expect(rechtJeKachel.keys.toSet(), quelleJeKachel.keys.toSet());
    });

    test('jede Datenquelle einer Kachel gibt es auch wirklich', () {
      for (final quelle in quelleJeKachel.values) {
        expect(rechtJeQuelle.containsKey(quelle), isTrue, reason: quelle);
      }
    });

    test('Kachel und Quelle verlangen dasselbe Recht', () {
      // Sonst würde eine Kachel ausgeblendet, obwohl ihre Daten geladen
      // werden — oder schlimmer: umgekehrt.
      for (final eintrag in rechtJeKachel.entries) {
        final quelle = quelleJeKachel[eintrag.key]!;
        expect(rechtJeQuelle[quelle], eintrag.value, reason: eintrag.key);
      }
    });

    test('jedes Recht heißt bereich:aktion', () {
      for (final recht in [
        ...rechtJeRoute.values,
        ...rechtJeKachel.values,
        ...rechtJeQuelle.values,
      ]) {
        expect(recht.split(':').length, 2, reason: recht);
      }
    });
  });
}

// ── Küchenmodus ────────────────────────────────────────────────────────

void _kuechenmodus() {
  group('Wer den Schalter sieht', () {
    test('nur mit tablet:use', () {
      final p = PermissionProvider();
      p.uebernehmen({'planner:read', 'tasks:read'});
      expect(p.darfTablet, isFalse);

      p.uebernehmen({'tablet:use'});
      expect(p.darfTablet, isTrue);
    });

    test('der Stern schließt es ein', () {
      final p = PermissionProvider();
      p.uebernehmen({'*'});
      expect(p.darfTablet, isTrue);
    });

    test('ohne geladene Rechte nicht', () {
      // Beim Start soll nicht kurz ein Schalter aufblitzen.
      expect(PermissionProvider().darfTablet, isFalse);
    });
  });

  group('Seiten aus dem Backend', () {
    test('Tablet-Seiten erkennen sich selbst', () {
      final s = DashboardSeite.fromJson({
        'id': 1, 'key': 'kueche', 'name': 'Küche',
        'mode': 'tablet', 'order_index': 0,
      });
      expect(s.istTablet, isTrue);
    });

    test('ohne Angabe ist es eine App-Seite', () {
      // Ein altes Backend ohne dieses Feld darf nicht dazu führen, dass
      // plötzlich alles in der Küchenansicht landet.
      final s = DashboardSeite.fromJson({
        'id': 1, 'key': 'home', 'name': 'Home', 'order_index': 0,
      });
      expect(s.mode, DashboardSeite.modeApp);
      expect(s.istTablet, isFalse);
    });
  });
}

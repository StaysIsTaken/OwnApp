// Was das Kuechen-Tablet an Kalendern sehen darf -- und was nicht.
//
// `tablet:use` schaltete lange beides frei: die Tablet-Oberflaeche UND die
// Kalender aller Hausgenossen. Das zweite war nie jemandes Entscheidung.
// Ausgerechnet am oeffentlichsten Bildschirm im Haus galt damit nicht,
// was sonst ueberall gilt -- eine Mitgliedschaft ist kein Einverstaendnis
// (dieselbe Regel wie bei `haushaltsFreigabe` und der Finanzsicht).
//
// Die beiden Rechte stehen jetzt getrennt, und diese Datei haelt genau das
// fest. Sie prueft eine reine Rechnung, keine Seite: der Endpunkt
// entscheidet ohnehin selbst, und was hier steht, soll nur verhindern,
// dass die App `alle: true` verlangt, wo sie es nicht darf.
//
// Gegenstueck im Backend: `tests/test_kalender_freigabe.py`.
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/provider/permission_provider.dart';

/// Ein Provider mit gesetzten Rechten -- ohne Netz.
PermissionProvider mitRechten(Set<String> rechte) {
  final p = PermissionProvider();
  p.setzeFuerTest(rechte);
  return p;
}

void main() {
  group('Das Tablet-Konto', () {
    test('darf die Oberflaeche, aber keine fremden Kalender', () {
      final tablet = mitRechten({'planner:read', 'tablet:use'});

      expect(tablet.darfTablet, isTrue);
      // Der Kern dieser Datei: die beiden haengen nicht mehr zusammen.
      expect(tablet.darfAlleKalender, isFalse);
    });

    test('mit dem Sonderrecht sieht es doch alle', () {
      // Wer dem Tablet trotzdem alles zeigen will, entscheidet das
      // ausdruecklich -- statt dass es nebenbei passiert.
      final tablet = mitRechten({'tablet:use', 'planner:read_all'});

      expect(tablet.darfTablet, isTrue);
      expect(tablet.darfAlleKalender, isTrue);
    });
  });

  group('Die uebrigen Konten', () {
    test('ein gewoehnliches Mitglied fragt gar nicht erst nach allen', () {
      final ich = mitRechten({'planner:read', 'planner:write'});

      expect(ich.darfTablet, isFalse);
      expect(ich.darfAlleKalender, isFalse);
    });

    test('der Admin darf beides ueber die Wildcard', () {
      final chef = mitRechten({'*'});

      expect(chef.darfTablet, isTrue);
      expect(chef.darfAlleKalender, isTrue);
    });
  });
}

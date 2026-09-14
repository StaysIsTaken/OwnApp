// Wer einen fremden Kalender lesen darf, entscheidet sein Besitzer.
//
// Vorher entschied das ein Recht: `planner:read_all` steckte in der
// Standardrolle, und damit sah jeder im Haushalt die nicht-privaten Termine
// aller anderen. Jetzt wird eingeladen -- wahlweise nur fuer bestimmte
// Termintypen, ein Stichwort im Titel oder beides.
//
// Geprueft wird hier, was ohne Netz pruefbar ist: was vom Server ankommt
// und wie die Oberflaeche daraus "hat einen Filter" ableitet. Der Dialog
// selbst haengt an drei HTTP-Aufrufen und ist hier nicht abgedeckt.
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/kalender_freigabe.dart';

void main() {
  group('Was vom Server ankommt', () {
    test('eine vollstaendige Freigabe wird gelesen', () {
      final f = KalenderFreigabe.fromJson({
        'calendar_id': 7,
        'user_id': 'u2',
        'user_name': 'Lisa',
        'filter_type_ids': [3, 5],
        'filter_keyword': 'Projekt',
      });
      expect(f.kalenderId, 7);
      expect(f.userName, 'Lisa');
      expect(f.typIds, [3, 5]);
      expect(f.stichwort, 'Projekt');
    });

    test('ohne Filter bleibt die Auswahl leer', () {
      final f = KalenderFreigabe.fromJson({
        'calendar_id': 1, 'user_id': 'u2', 'user_name': 'Lisa',
        'filter_type_ids': <int>[], 'filter_keyword': null,
      });
      expect(f.typIds, isEmpty);
      expect(f.stichwort, isNull);
    });

    test('ein leeres Stichwort ist kein Stichwort', () {
      // Sonst stuende in der Liste „enthaelt „"" -- und schlimmer: die
      // Oberflaeche wuerde einen Filter behaupten, den es nicht gibt.
      final f = KalenderFreigabe.fromJson({
        'calendar_id': 1, 'user_id': 'u2', 'user_name': 'Lisa',
        'filter_keyword': '',
      });
      expect(f.stichwort, isNull);
      expect(f.hatFilter, isFalse);
    });

    test('fehlende Felder kippen das Lesen nicht', () {
      final f = KalenderFreigabe.fromJson({'user_id': 'u2'});
      expect(f.kalenderId, 0);
      expect(f.userName, '?');
      expect(f.typIds, isEmpty);
    });
  });

  group('Hat diese Freigabe einen Filter?', () {
    // Davon haengt ab, ob in der Liste „alles ausser Privatem" steht oder
    // die Aufzaehlung -- also ob der Besitzer auf einen Blick sieht, dass
    // er jemandem den ganzen Kalender geoeffnet hat.
    KalenderFreigabe mit({List<int> typen = const [], String? wort}) =>
        KalenderFreigabe(
          kalenderId: 1, userId: 'u2', userName: 'Lisa',
          typIds: typen, stichwort: wort,
        );

    test('ohne alles: kein Filter', () {
      expect(mit().hatFilter, isFalse);
    });

    test('nur Typen: Filter', () {
      expect(mit(typen: [3]).hatFilter, isTrue);
    });

    test('nur Stichwort: Filter', () {
      expect(mit(wort: 'Fussball').hatFilter, isTrue);
    });

    test('beides: Filter', () {
      expect(mit(typen: [3], wort: 'Fussball').hatFilter, isTrue);
    });

    test('ein leeres Stichwort allein ist kein Filter', () {
      expect(mit(wort: '').hatFilter, isFalse);
    });
  });
}

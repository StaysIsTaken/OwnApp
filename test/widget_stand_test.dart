import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/dataclasses/task.dart';
import 'package:productivity/dataservice/widget_stand.dart';

/// Der Stand, den das Startbildschirm-Widget zeichnet.
///
/// Das Widget selbst ist Swift und lässt sich hier nicht prüfen. Was es
/// zu sehen bekommt, schon — und dort liegen die Fehler, die man auf dem
/// Telefon erst nach Tagen bemerkt: ein vergangener Termin, der stehen
/// bleibt, oder eine Uhrzeit, die um eine Stunde verrutscht.

final _jetzt = DateTime(2026, 9, 25, 10, 0);

PlannerEntry _termin(
  int id,
  DateTime beginn, {
  Duration dauer = const Duration(hours: 1),
  int? parentId,
  String titel = 'Termin',
}) =>
    PlannerEntry(
      id: id,
      userId: 'u',
      title: titel,
      scheduledAt: beginn,
      endsAt: beginn.add(dauer),
      createdAt: _jetzt,
      parentId: parentId,
    );

Task _aufgabe(String id, {DateTime? faellig, bool erledigt = false}) => Task(
      id: id,
      title: 'Aufgabe $id',
      dueDate: faellig,
      completed: erledigt,
      userId: 'u',
      createdAt: _jetzt,
      updatedAt: _jetzt,
    );

Map<String, dynamic> _baue({
  List<Task> aufgaben = const [],
  List<PlannerEntry> termine = const [],
}) =>
    WidgetStand.baue(aufgaben: aufgaben, termine: termine, jetzt: _jetzt);

List<String> _titel(Map<String, dynamic> stand) =>
    [for (final t in stand['termine'] as List) t['titel'] as String];

void main() {
  group('Termine', () {
    test('was vorbei ist, fällt weg; was läuft, bleibt', () {
      final stand = _baue(termine: [
        _termin(1, DateTime(2026, 9, 25, 8), titel: 'vorbei'),
        _termin(2, DateTime(2026, 9, 25, 9, 30), titel: 'läuft'),
        _termin(3, DateTime(2026, 9, 25, 14), titel: 'kommt'),
      ]);

      expect(_titel(stand), ['läuft', 'kommt']);
    });

    test('nur die nächsten sieben Tage', () {
      final stand = _baue(termine: [
        _termin(1, DateTime(2026, 10, 1, 9), titel: 'in sechs Tagen'),
        _termin(2, DateTime(2026, 10, 3, 9), titel: 'in acht Tagen'),
      ]);

      expect(_titel(stand), ['in sechs Tagen']);
    });

    test('nach Beginn sortiert, egal wie der Server sie schickt', () {
      final stand = _baue(termine: [
        _termin(1, DateTime(2026, 9, 26, 9), titel: 'morgen'),
        _termin(2, DateTime(2026, 9, 25, 12), titel: 'heute'),
      ]);

      expect(_titel(stand), ['heute', 'morgen']);
    });

    test('Untertermine stehen nicht als eigene Termine da', () {
      final stand = _baue(termine: [
        _termin(1, DateTime(2026, 9, 25, 12), titel: 'Umzug'),
        _termin(2, DateTime(2026, 9, 25, 12), parentId: 1, titel: 'Kartons'),
      ]);

      expect(_titel(stand), ['Umzug']);
    });

    test('höchstens so viele, wie ins Widget passen', () {
      final stand = _baue(termine: [
        for (var i = 0; i < 30; i++)
          _termin(i, _jetzt.add(Duration(hours: i + 1))),
      ]);

      expect((stand['termine'] as List).length, WidgetStand.hoechstensTermine);
    });

    test('Zeiten als Sekunden seit 1970 — ohne Zone zum Raten', () {
      final beginn = DateTime(2026, 9, 25, 14, 30);
      final stand = _baue(termine: [_termin(1, beginn)]);
      final t = (stand['termine'] as List).single as Map;

      expect(t['beginn'], beginn.millisecondsSinceEpoch ~/ 1000);
      expect(t['ende'],
          beginn.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000);
    });

    test('ganztägig kommt aus derselben Regel wie im Planer', () {
      final ganztag = PlannerEntry(
        id: 1,
        userId: 'u',
        title: 'Feiertag',
        scheduledAt: DateTime(2026, 9, 26),
        endsAt: DateTime(2026, 9, 26, 23, 59),
        createdAt: _jetzt,
      );
      final stand = _baue(termine: [ganztag]);

      expect((stand['termine'] as List).single['ganztag'], isTrue);
    });
  });

  group('Aufgaben', () {
    test('nur offene, fällige zuerst, ohne Datum zuletzt', () {
      final stand = _baue(aufgaben: [
        _aufgabe('ohne'),
        _aufgabe('spaeter', faellig: DateTime(2026, 9, 30)),
        _aufgabe('erledigt', faellig: DateTime(2026, 9, 20), erledigt: true),
        _aufgabe('frueher', faellig: DateTime(2026, 9, 24)),
      ]);

      expect(
        [for (final a in stand['aufgaben'] as List) a['titel']],
        ['Aufgabe frueher', 'Aufgabe spaeter', 'Aufgabe ohne'],
      );
      expect(stand['aufgabenOffen'], 3);
    });

    test('die Zahl zählt alle offenen, auch die abgeschnittenen', () {
      final stand = _baue(aufgaben: [
        for (var i = 0; i < 10; i++) _aufgabe('$i'),
      ]);

      expect((stand['aufgaben'] as List).length, WidgetStand.hoechstensAufgaben);
      expect(stand['aufgabenOffen'], 10);
    });

    test('fällig als Kalendertag, nicht als Zeitpunkt', () {
      final stand = _baue(aufgaben: [
        _aufgabe('a', faellig: DateTime(2026, 9, 3, 23, 30)),
      ]);

      expect((stand['aufgaben'] as List).single['faellig'], '2026-09-03');
    });
  });

  group('Form', () {
    test('lässt sich als JSON schreiben und trägt Fassung und Stand', () {
      final stand = _baue(
        aufgaben: [_aufgabe('a', faellig: _jetzt)],
        termine: [_termin(1, DateTime(2026, 9, 25, 12))],
      );
      final zurueck = jsonDecode(jsonEncode(stand)) as Map<String, dynamic>;

      expect(zurueck['fassung'], WidgetStand.fassung);
      expect(zurueck['stand'], _jetzt.millisecondsSinceEpoch ~/ 1000);
      // Genau diese Schlüssel liest ios/OwnAppWidget/OwnAppWidget.swift.
      expect((zurueck['termine'] as List).single.keys,
          containsAll(['titel', 'beginn', 'ende', 'ganztag', 'farbe']));
      expect((zurueck['aufgaben'] as List).single.keys,
          containsAll(['titel', 'faellig', 'prioritaet']));
    });

    test('nach dem Abmelden steht nichts vom vorigen Konto darin', () {
      final leer = WidgetStand.leer(_jetzt);

      expect(leer['abgemeldet'], isTrue);
      expect(leer['termine'], isEmpty);
      expect(leer['aufgaben'], isEmpty);
      expect(leer['aufgabenOffen'], 0);
      expect(leer['fassung'], WidgetStand.fassung);
    });
  });
}

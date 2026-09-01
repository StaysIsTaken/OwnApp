// Prüft die reine Planungslogik: welche Erinnerungen entstehen, in welcher
// Reihenfolge, und was beim iOS-Limit von 64 wegfällt.
//
// Bewusst ohne Plattform-Aufrufe – `plan()` ist absichtlich nebenwirkungsfrei,
// damit genau das hier testbar ist.
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/dataclasses/task.dart';
import 'package:productivity/dataservice/local_notification_manager.dart';
import 'package:productivity/dataservice/notification_scheduler.dart';
import 'package:productivity/dataservice/planner_notification_scheduler.dart';
import 'package:productivity/dataservice/task_notification_scheduler.dart';

PlannerEntry termin({
  required int id,
  required DateTime start,
  int vorlauf = 10,
  String titel = 'Zahnarzt',
  String? beschreibung,
  int? parentId,
}) =>
    PlannerEntry(
      id: id,
      userId: 'u1',
      createdAt: DateTime(2026, 1, 1),
      title: titel,
      description: beschreibung,
      scheduledAt: start,
      endsAt: start.add(const Duration(hours: 1)),
      notifyMinBefore: vorlauf,
      parentId: parentId,
    );

Task aufgabe({required String id, DateTime? faellig, bool erledigt = false}) =>
    Task(
      id: id,
      title: 'Aufgabe $id',
      dueDate: faellig,
      completed: erledigt,
      userId: 'u1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

void main() {
  final jetzt = DateTime.now();

  group('Termin-Erinnerungen', () {
    test('werden um den Vorlauf vor Beginn geplant', () {
      final start = jetzt.add(const Duration(days: 2));
      final geplant = PlannerNotificationScheduler.plan(
        termin(id: 1, start: start, vorlauf: 15),
      );

      expect(geplant, hasLength(1));
      expect(
        geplant.first.when,
        start.subtract(const Duration(minutes: 15)),
      );
      expect(geplant.first.channelId, LocalNotificationManager.channelPlanner);
      expect(geplant.first.payload, 'planner:1');
    });

    test('entfallen, wenn der Zeitpunkt schon vorbei ist', () {
      final vergangen = jetzt.subtract(const Duration(hours: 3));
      expect(PlannerNotificationScheduler.plan(termin(id: 2, start: vergangen)),
          isEmpty);
    });

    test('entfallen knapp, wenn der Vorlauf bereits angebrochen ist', () {
      // Termin in 5 Minuten, Vorlauf 10 -> Zeitpunkt läge in der Vergangenheit
      final gleich = jetzt.add(const Duration(minutes: 5));
      expect(
        PlannerNotificationScheduler.plan(
            termin(id: 3, start: gleich, vorlauf: 10)),
        isEmpty,
      );
    });

    test('Untertermine erben die Erinnerung des Haupttermins', () {
      final start = jetzt.add(const Duration(days: 1));
      expect(
        PlannerNotificationScheduler.plan(
            termin(id: 4, start: start, parentId: 99)),
        isEmpty,
      );
    });

    test('Beschreibung landet im Text', () {
      final start = jetzt.add(const Duration(days: 1));
      final n = PlannerNotificationScheduler.plan(
        termin(id: 5, start: start, beschreibung: 'Praxis Dr. Müller'),
      ).first;
      expect(n.body, contains('Praxis Dr. Müller'));
    });

    test('IDs kollidieren nicht mit denen der Aufgaben', () {
      final plannerId = PlannerNotificationScheduler.idFor(1);
      expect(plannerId, greaterThanOrEqualTo(PlannerNotificationScheduler.idBase));
      expect(
        plannerId,
        greaterThan(TaskNotificationScheduler.baseDayBefore +
            TaskNotificationScheduler.idRangeSize - 1),
      );
    });
  });

  group('Gemeinsames Budget', () {
    test('Limit liegt unter dem iOS-Maximum von 64', () {
      expect(NotificationScheduler.maxPending, lessThan(64));
    });

    test('sortiert Aufgaben und Termine gemeinsam nach Zeitpunkt', () {
      // Termin in 1 Tag, Aufgabe in 5 Tagen -> Termin muss zuerst kommen.
      final t = PlannerNotificationScheduler.plan(
        termin(id: 10, start: jetzt.add(const Duration(days: 1)), vorlauf: 0),
      );
      final a = TaskNotificationScheduler.plan(
        aufgabe(id: 'a1', faellig: jetzt.add(const Duration(days: 5))),
      );
      final zusammen = [...t, ...a]..sort((x, y) => x.when.compareTo(y.when));

      expect(zusammen.first.payload, 'planner:10');
    });

    test('erledigte Aufgaben erzeugen nichts', () {
      expect(
        TaskNotificationScheduler.plan(
            aufgabe(id: 'a2', faellig: jetzt.add(const Duration(days: 3)), erledigt: true)),
        isEmpty,
      );
    });

    test('Aufgaben ohne Fälligkeit erzeugen nichts', () {
      expect(TaskNotificationScheduler.plan(aufgabe(id: 'a3')), isEmpty);
    });
  });
}

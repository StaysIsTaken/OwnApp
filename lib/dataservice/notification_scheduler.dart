import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/dataclasses/task.dart';
import 'package:productivity/dataservice/local_notification_manager.dart';
import 'package:productivity/dataservice/planned_notification.dart';
import 'package:productivity/dataservice/planner_notification_scheduler.dart';
import 'package:productivity/dataservice/task_notification_scheduler.dart';

/// Meldet die anstehenden Erinnerungen für Aufgaben UND Termine gemeinsam an.
///
/// Warum gemeinsam: iOS merkt sich höchstens **64 vorgemerkte Mitteilungen pro
/// App**. Alles darüber wird stillschweigend verworfen – ohne Fehler, ohne
/// Log. Wer Aufgaben und Termine getrennt einplant, kann dieses Limit nicht
/// einhalten, weil keine Seite die andere kennt.
///
/// Deshalb: alle Kandidaten einsammeln, nach Zeitpunkt sortieren, die
/// nächstliegenden behalten. Was hinten abfällt, ist weit genug weg, dass es
/// der nächste Hintergrund-Sync noch rechtzeitig nachträgt.
class NotificationScheduler {
  NotificationScheduler._();

  /// Etwas unter dem iOS-Limit von 64, damit sofort angezeigte Mitteilungen
  /// (Chat, Vorrat) nicht ins Gedränge kommen.
  static const int maxPending = 58;

  /// Zahlenraum, den dieser Scheduler verwaltet. Nur Mitteilungen daraus
  /// werden beim Neuplanen abgeräumt – sonst würden fremde (z.B. bereits
  /// sichtbare Chat-Hinweise) mit gelöscht.
  static const int _managedFrom = TaskNotificationScheduler.baseDayOf;
  static const int _managedTo =
      PlannerNotificationScheduler.idBase + PlannerNotificationScheduler.idRangeSize;

  /// Räumt alle verwalteten Erinnerungen ab und plant sie neu ein.
  ///
  /// Gibt zurück, wie viele tatsächlich angemeldet wurden – nützlich, um im
  /// Zweifel zu sehen, ob das Budget greift.
  static Future<int> rescheduleAll({
    List<Task> tasks = const [],
    List<PlannerEntry> plannerEntries = const [],
  }) async {
    final kandidaten = <PlannedNotification>[
      for (final t in tasks) ...TaskNotificationScheduler.plan(t),
      for (final e in plannerEntries) ...PlannerNotificationScheduler.plan(e),
    ]..sort((a, b) => a.when.compareTo(b.when));

    final auswahl = kandidaten.take(maxPending).toList();

    await _cancelManaged();
    for (final n in auswahl) {
      await LocalNotificationManager().scheduleNotification(
        id: n.id,
        title: n.title,
        body: n.body,
        when: n.when,
        channelId: n.channelId,
        payload: n.payload,
      );
    }
    return auswahl.length;
  }

  /// Entfernt nur die Mitteilungen aus dem eigenen Zahlenraum.
  static Future<void> _cancelManaged() async {
    final offen = await LocalNotificationManager().pending();
    for (final n in offen) {
      if (n.id >= _managedFrom && n.id < _managedTo) {
        await LocalNotificationManager().cancel(n.id);
      }
    }
  }
}

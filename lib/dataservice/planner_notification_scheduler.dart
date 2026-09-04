import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/dataservice/local_notification_manager.dart';
import 'package:productivity/dataservice/planned_notification.dart';

/// Plant lokale Erinnerungen für Termine.
///
/// Zeitpunkt = `scheduledAt` minus `notifyMinBefore`. Die Mitteilung wird beim
/// Betriebssystem hinterlegt und erscheint auch bei geschlossener App – dafür
/// braucht es weder Server noch Push-Zertifikat.
///
/// Das `notified`-Flag aus dem Backend wird bewusst ignoriert: es gehört zum
/// n8n-Weg und gilt pro Konto, nicht pro Gerät. Für lokale Erinnerungen zählt
/// allein, ob der Zeitpunkt noch in der Zukunft liegt.
class PlannerNotificationScheduler {
  PlannerNotificationScheduler._();

  /// Eigener Zahlenraum, damit sich IDs nicht mit denen der Aufgaben
  /// (3.000.000 / 4.000.000) überschneiden.
  static const int idBase = 5000000;
  static const int idRangeSize = 1000000;

  /// Baut die Erinnerung, ohne sie anzumelden.
  static List<PlannedNotification> plan(PlannerEntry entry) {
    // Untertermine erben die Erinnerung des Haupttermins – sonst klingelt es
    // bei einem Termin mit fünf Unterpunkten sechsmal.
    if (entry.parentId != null) return const [];

    final vorlauf = entry.notifyMinBefore;
    final wann = entry.scheduledAt.subtract(Duration(minutes: vorlauf));
    if (!wann.isAfter(DateTime.now())) return const [];

    final zeit = _formatTime(entry.scheduledAt);
    final body = vorlauf > 0
        ? 'Beginnt um $zeit (in $vorlauf ${vorlauf == 1 ? 'Minute' : 'Minuten'}).'
        : 'Beginnt jetzt um $zeit.';

    return [
      PlannedNotification(
        id: idFor(entry.id),
        title: '📅 ${entry.title}',
        body: entry.description?.isNotEmpty == true
            ? '${entry.description}\n$body'
            : body,
        when: wann,
        channelId: LocalNotificationManager.channelPlanner,
        payload: 'planner:${entry.id}',
      ),
    ];
  }

  /// Plant die Erinnerung für einen einzelnen Termin ein.
  static Future<void> schedule(PlannerEntry entry) async {
    await cancel(entry.id);
    for (final n in plan(entry)) {
      await LocalNotificationManager().scheduleNotification(
        id: n.id,
        title: n.title,
        body: n.body,
        when: n.when,
        channelId: n.channelId,
        payload: n.payload,
      );
    }
  }

  static Future<void> cancel(int entryId) async {
    await LocalNotificationManager().cancel(idFor(entryId));
  }

  static int idFor(int entryId) => idBase + (entryId.abs() % idRangeSize);

  static String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

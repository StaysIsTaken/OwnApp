/// Eine geplante Mitteilung, noch nicht beim System angemeldet.
///
/// Aufgaben und Termine erzeugen daraus Listen, die der
/// `NotificationScheduler` gemeinsam sortiert und budgetiert. Ohne diesen
/// Zwischenschritt könnte jede Quelle nur ihr eigenes Kontingent kennen –
/// iOS zählt aber alle zusammen.
class PlannedNotification {
  final int id;
  final String title;
  final String body;
  final DateTime when;
  final String channelId;
  final String? payload;

  const PlannedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
    required this.channelId,
    this.payload,
  });
}

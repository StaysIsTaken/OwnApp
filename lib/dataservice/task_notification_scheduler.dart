import 'package:productivity/dataclasses/task.dart';
import 'package:productivity/dataservice/local_notification_manager.dart';

/// Schedules and cancels local notifications for tasks based on their
/// due-date.
///
/// A task gets up to two notifications:
///  - At 09:00 the morning of the due date (only if the due date is at
///    least one day in the future when the task is created).
///  - At 09:00 the day before the due date (early warning – only if the
///    due date is more than one day away).
///
/// IDs are derived from the task ID so each task can be cancelled and
/// re-scheduled deterministically.
class TaskNotificationScheduler {
  TaskNotificationScheduler._();

  static const int _baseDayOf = 3000000;   // Day of due date
  static const int _baseDayBefore = 4000000; // Day before due date

  /// Schedules notifications for the given task.
  /// If the task is completed or has no due date, nothing happens.
  static Future<void> schedule(Task task) async {
    // Always cancel previous notifications first to avoid duplicates if the
    // due date changed.
    await cancel(task.id);

    if (task.completed || task.dueDate == null) return;

    final dueDate = task.dueDate!;
    final now = DateTime.now();

    // Scheduled time = due date at 09:00 local time
    final dueAt9 = DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0);

    // 1. Notification at 09:00 of the due day
    if (dueAt9.isAfter(now)) {
      await LocalNotificationManager().scheduleNotification(
        id: _idForDayOf(task.id),
        title: '📋 Task fällig: ${task.title}',
        body: task.description?.isNotEmpty == true
            ? task.description!
            : 'Diese Task ist heute fällig.',
        when: dueAt9,
        channelId: LocalNotificationManager.channelTasks,
        payload: 'task:${task.id}',
      );
    }

    // 2. Early warning the day before, also at 09:00
    final dayBefore = dueAt9.subtract(const Duration(days: 1));
    if (dayBefore.isAfter(now)) {
      await LocalNotificationManager().scheduleNotification(
        id: _idForDayBefore(task.id),
        title: '⏰ Bald fällig: ${task.title}',
        body: 'Erinnerung: Diese Task ist morgen fällig.',
        when: dayBefore,
        channelId: LocalNotificationManager.channelTasks,
        payload: 'task:${task.id}',
      );
    }
  }

  /// Cancels both notifications for the given task ID.
  static Future<void> cancel(String taskId) async {
    await LocalNotificationManager().cancel(_idForDayOf(taskId));
    await LocalNotificationManager().cancel(_idForDayBefore(taskId));
  }

  /// Re-schedules notifications for ALL given tasks. Useful for periodic
  /// background syncs that pick up new tasks created on other devices.
  static Future<void> rescheduleAll(List<Task> tasks) async {
    for (final t in tasks) {
      await schedule(t);
    }
  }

  // ──── ID helpers ────────────────────────────────────
  static int _idForDayOf(String taskId) {
    final hash = taskId.hashCode & 0x7FFFFFFF;
    return _baseDayOf + (hash % 1000000);
  }

  static int _idForDayBefore(String taskId) {
    final hash = taskId.hashCode & 0x7FFFFFFF;
    return _baseDayBefore + (hash % 1000000);
  }
}

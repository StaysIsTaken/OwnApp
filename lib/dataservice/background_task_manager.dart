import 'package:flutter/foundation.dart';
import 'package:productivity/dataclasses/pantry_item.dart';
import 'package:productivity/dataclasses/ingredient.dart';
import 'package:productivity/dataservice/local_notification_manager.dart';
import 'package:productivity/dataservice/login_service.dart';
import 'package:productivity/dataservice/task_service.dart';
import 'package:productivity/dataservice/pantry_service.dart';
import 'package:productivity/dataservice/ingredient_service.dart';
import 'package:productivity/dataservice/task_notification_scheduler.dart';
import 'package:workmanager/workmanager.dart';

// ─────────────────────────────────────────────
//  Background Task Names (used by Workmanager)
// ─────────────────────────────────────────────
const String taskPeriodicSync = 'periodicSync';
const String taskSyncTaskNotifications = 'syncTaskNotifications';

// ─────────────────────────────────────────────
//  Top-level callback dispatcher for Workmanager
//  Must be a top-level/static function and annotated with
//  `@pragma('vm:entry-point')` so it survives tree-shaking in release.
// ─────────────────────────────────────────────
@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Make sure local notifications are initialized in this isolate
      await LocalNotificationManager().init();

      // Don't bother running if user isn't logged in any more
      final loggedIn = await LoginService.isLoggedIn();
      if (!loggedIn) return true;

      switch (task) {
        case taskPeriodicSync:
          await BackgroundTaskManager._runPeriodicSync();
          break;
        case taskSyncTaskNotifications:
          await BackgroundTaskManager._syncTaskNotifications();
          break;
      }
      return true;
    } catch (e) {
      // Returning true so Workmanager doesn't immediately retry on a transient
      // error (like no network). The next periodic run will pick up the work.
      return true;
    }
  });
}

class BackgroundTaskManager {
  BackgroundTaskManager._();

  static bool _initialized = false;

  /// Initializes Workmanager and schedules the recurring background tasks.
  static Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) return; // Workmanager not supported on web
    if (!_supportedPlatform) return;

    await Workmanager().initialize(
      backgroundCallbackDispatcher,
      isInDebugMode: false,
    );

    // Daily background sync ─ checks pantry expiry / low stock and reschedules
    // any task notifications that may have been added on another device.
    // Android enforces a 15-minute minimum frequency.
    await Workmanager().registerPeriodicTask(
      taskPeriodicSync,
      taskPeriodicSync,
      frequency: const Duration(hours: 6),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.connected),
      initialDelay: const Duration(minutes: 1),
    );

    _initialized = true;
  }

  /// Stops all background work (e.g. on logout).
  static Future<void> stop() async {
    if (kIsWeb || !_supportedPlatform) return;
    await Workmanager().cancelAll();
    _initialized = false;
  }

  static bool get _supportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  // ──────────────────────────────────────────────
  //  Background Work Implementations
  // ──────────────────────────────────────────────

  static Future<void> _runPeriodicSync() async {
    await _syncTaskNotifications();
    await _checkPantryStatus();
  }

  /// Pulls fresh tasks from the server and (re)schedules local notifications
  /// for tasks that the user might have created on another device.
  static Future<void> _syncTaskNotifications() async {
    try {
      final tasks = await TaskService.loadAll(limit: 200);
      await TaskNotificationScheduler.rescheduleAll(tasks);
    } catch (_) {
      // ignore – will retry on next run
    }
  }

  /// Checks the pantry for low stock and items expiring soon, then shows
  /// system notifications for them.
  static Future<void> _checkPantryStatus() async {
    try {
      final results = await Future.wait([
        PantryService.loadAll(),
        IngredientService.loadAll(),
      ]);
      final pantry = results[0] as List<PantryItem>;
      final ingredients = results[1] as List<Ingredient>;
      final ingMap = {for (final i in ingredients) i.id: i};

      // 1. Items expiring within the next 3 days
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final expiringSoon = pantry.where((p) {
        if (p.expiryDate == null) return false;
        final expiry = DateTime(
          p.expiryDate!.year,
          p.expiryDate!.month,
          p.expiryDate!.day,
        );
        final daysUntil = expiry.difference(today).inDays;
        return daysUntil >= 0 && daysUntil <= 3;
      }).toList();

      if (expiringSoon.isNotEmpty) {
        final names = expiringSoon
            .take(3)
            .map((p) => ingMap[p.ingredientId]?.name ?? '?')
            .join(', ');
        final extra = expiringSoon.length > 3
            ? ' und ${expiringSoon.length - 3} weitere'
            : '';
        await LocalNotificationManager().showNotification(
          id: 5001,
          title: '⚠️ Vorräte laufen bald ab',
          body: '$names$extra. Verbrauche oder ersetze sie.',
          channelId: LocalNotificationManager.channelPantry,
          payload: 'pantry:expiring',
        );
      }

      // 2. Items below their minimum stock level
      final lowStock = pantry.where((p) => p.amount <= p.minAmount).toList();
      if (lowStock.isNotEmpty) {
        final names = lowStock
            .take(3)
            .map((p) => ingMap[p.ingredientId]?.name ?? '?')
            .join(', ');
        final extra = lowStock.length > 3
            ? ' und ${lowStock.length - 3} weitere'
            : '';
        await LocalNotificationManager().showNotification(
          id: 5002,
          title: '🛒 Vorräte werden knapp',
          body: '$names$extra. Vielleicht Zeit für einen Einkauf?',
          channelId: LocalNotificationManager.channelPantry,
          payload: 'pantry:lowstock',
        );
      }
    } catch (_) {
      // ignore – will retry on next run
    }
  }
}

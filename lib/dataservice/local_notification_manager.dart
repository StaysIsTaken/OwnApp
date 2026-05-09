import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Manages local (device-side) notifications.
///
/// Three notification channels are used:
///  - tasks       → for due tasks reminders
///  - pantry      → for low stock / expiring items
///  - chat        → for new chat messages
///
/// The channels are registered once at startup. Notifications can be:
///  - shown immediately (e.g. via WebSocket events)
///  - scheduled at a specific time (e.g. when a task is due)
class LocalNotificationManager {
  LocalNotificationManager._internal();
  static final LocalNotificationManager _instance =
      LocalNotificationManager._internal();
  factory LocalNotificationManager() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ──── Channel IDs ────────────────────────────────────
  static const String channelTasks = 'tasks_channel';
  static const String channelPantry = 'pantry_channel';
  static const String channelChat = 'chat_channel';

  // ──── User-controllable Settings (SharedPreferences keys) ────
  static const String prefEnabled = 'notif_enabled';
  static const String prefChat = 'notif_chat';
  static const String prefTasks = 'notif_tasks';
  static const String prefPantry = 'notif_pantry';

  // ──── Initialization ─────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) return; // Web does not support flutter_local_notifications

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    _initialized = true;
  }

  /// Requests OS-level notification permissions.
  /// Returns `true` if granted.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    // Android 13+ requires runtime permission
    final notifStatus = await Permission.notification.request();
    final granted = notifStatus.isGranted;

    // For exact alarm scheduling on Android 12+
    if (granted) {
      final scheduleStatus = await Permission.scheduleExactAlarm.status;
      if (scheduleStatus.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    }

    // iOS permissions
    final iosImpl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      await iosImpl.requestPermissions(alert: true, badge: true, sound: true);
    }

    return granted;
  }

  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return false;
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      return await androidImpl.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  // ──── User Settings ──────────────────────────────────
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefEnabled) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefEnabled, value);
    if (!value) {
      await cancelAll();
    }
  }

  Future<bool> isCategoryEnabled(String prefKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKey) ?? true;
  }

  Future<void> setCategoryEnabled(String prefKey, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, value);
  }

  // ──── Show Immediately ───────────────────────────────
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    String? payload,
  }) async {
    if (kIsWeb || !_initialized) return;
    if (!await isEnabled()) return;
    if (!await _isChannelAllowed(channelId)) return;

    final details = _buildNotificationDetails(channelId);
    await _plugin.show(id, title, body, details, payload: payload);
  }

  // ──── Schedule at specific Time ──────────────────────
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String channelId,
    String? payload,
  }) async {
    if (kIsWeb || !_initialized) return;
    if (!await isEnabled()) return;
    if (!await _isChannelAllowed(channelId)) return;
    if (when.isBefore(DateTime.now())) return; // Don't schedule in the past

    final details = _buildNotificationDetails(channelId);
    final tzWhen = tz.TZDateTime.from(when, tz.local);

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzWhen,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      // Fallback to inexact scheduling if exact alarm not allowed
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tzWhen,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      } catch (_) {
        // Silent fail
      }
    }
  }

  // ──── Cancel ────────────────────────────────────────
  Future<void> cancel(int id) async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancelAll();
  }

  /// Returns IDs of currently scheduled (not yet shown) notifications.
  Future<List<PendingNotificationRequest>> pending() async {
    if (kIsWeb || !_initialized) return [];
    return await _plugin.pendingNotificationRequests();
  }

  // ──── Internal Helpers ──────────────────────────────
  Future<bool> _isChannelAllowed(String channelId) async {
    if (channelId == channelTasks) return await isCategoryEnabled(prefTasks);
    if (channelId == channelPantry) return await isCategoryEnabled(prefPantry);
    if (channelId == channelChat) return await isCategoryEnabled(prefChat);
    return true;
  }

  NotificationDetails _buildNotificationDetails(String channelId) {
    final androidDetails = _androidDetailsFor(channelId);
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  AndroidNotificationDetails _androidDetailsFor(String channelId) {
    switch (channelId) {
      case channelTasks:
        return const AndroidNotificationDetails(
          channelTasks,
          'Tasks',
          channelDescription: 'Erinnerungen für fällige Tasks',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        );
      case channelPantry:
        return const AndroidNotificationDetails(
          channelPantry,
          'Vorräte',
          channelDescription:
              'Warnungen bei niedrigen Beständen und ablaufenden Vorräten',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        );
      case channelChat:
        return const AndroidNotificationDetails(
          channelChat,
          'Chat',
          channelDescription: 'Neue Nachrichten im Chat',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        );
      default:
        return const AndroidNotificationDetails(
          'default_channel',
          'Allgemein',
          channelDescription: 'Allgemeine Benachrichtigungen',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        );
    }
  }

  static void _handleNotificationTap(NotificationResponse response) {
    // Notification was tapped. Payload could be used for routing.
    // Example: payload = "task:abc-123" → could route to tasks page
    // Currently we just open the app (which is the default behavior).
  }
}

import 'package:productivity/dataservice/api_client.dart';

/// Journal-Erinnerung serverseitig speichern/abrufen. Das Backend löst die
/// Erinnerung zur Uhrzeit aus (schickt an n8n -> ntfy/Push).
class JournalReminderService {
  JournalReminderService._();
  static const String _path = '/journal/reminder';

  static Future<({bool enabled, int hour, int minute})> get() async {
    final r = await ApiClient.dio.get(_path);
    final d = Map<String, dynamic>.from(r.data as Map);
    return (
      enabled: d['enabled'] == true,
      hour: (d['hour'] as num?)?.toInt() ?? 20,
      minute: (d['minute'] as num?)?.toInt() ?? 0,
    );
  }

  static Future<void> save({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    await ApiClient.dio.put(_path, data: {
      'enabled': enabled,
      'hour': hour,
      'minute': minute,
    });
  }
}

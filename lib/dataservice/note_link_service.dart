import 'package:productivity/dataclasses/note_link.dart';
import 'package:productivity/dataservice/api_client.dart';

class NoteLinkService {
  NoteLinkService._();
  static const String _path = '/note-links';

  static Future<void> createLink(String sourceNoteId, String targetNoteId) async {
    try {
      await ApiClient.dio.post(
        _path,
        data: {
          'sourceNoteId': sourceNoteId,
          'targetNoteId': targetNoteId,
        },
      );
    } catch (e) {
      throw Exception('Fehler beim Erstellen des Links: $e');
    }
  }

  static Future<void> deleteLink(String sourceNoteId, String targetNoteId) async {
    try {
      await ApiClient.dio.delete(
        '$_path/$sourceNoteId/$targetNoteId',
      );
    } catch (e) {
      throw Exception('Fehler beim Löschen des Links: $e');
    }
  }

  static Future<List<NoteLink>> getLinksFromNote(String sourceNoteId) async {
    try {
      final response = await ApiClient.dio.get('$_path/from/$sourceNoteId');

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data is List ? response.data : [];
        return items.map((item) => NoteLink.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Fehler beim Laden der ausgehenden Links: $e');
    }
  }

  static Future<List<NoteLink>> getLinksToNote(String targetNoteId) async {
    try {
      final response = await ApiClient.dio.get('$_path/to/$targetNoteId');

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data is List ? response.data : [];
        return items.map((item) => NoteLink.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Fehler beim Laden der eingehenden Links: $e');
    }
  }
}

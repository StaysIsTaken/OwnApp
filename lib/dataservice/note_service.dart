import 'package:productivity/dataclasses/note.dart';
import 'package:productivity/dataclasses/note_link.dart';
import 'package:productivity/dataservice/api_client.dart';

class NoteService {
  NoteService._();
  static const String _path = '/notes';

  static Future<List<Note>> loadAll({
    String? folderId,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (folderId != null) {
        queryParams['folder_id'] = folderId;
      }

      final response = await ApiClient.dio.get(_path, queryParameters: queryParams);

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data is List ? response.data : [];
        return items.map((item) => Note.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Fehler beim Laden der Notizen: $e');
    }
  }

  static Future<Note> getById(String id) async {
    try {
      final response = await ApiClient.dio.get('$_path/$id');
      return Note.fromJson(response.data);
    } catch (e) {
      throw Exception('Fehler beim Laden der Notiz: $e');
    }
  }

  static Future<Note> create(Note note) async {
    try {
      final response = await ApiClient.dio.post(
        _path,
        data: note.toJson(),
      );
      return Note.fromJson(response.data);
    } catch (e) {
      throw Exception('Fehler beim Erstellen der Notiz: $e');
    }
  }

  static Future<Note> update(Note note) async {
    try {
      final response = await ApiClient.dio.put(
        '$_path/${note.id}',
        data: note.toJson(),
      );
      return Note.fromJson(response.data);
    } catch (e) {
      throw Exception('Fehler beim Aktualisieren der Notiz: $e');
    }
  }

  static Future<void> delete(String id) async {
    try {
      await ApiClient.dio.delete('$_path/$id');
    } catch (e) {
      throw Exception('Fehler beim Löschen der Notiz: $e');
    }
  }

  static Future<List<Note>> getFolderNotes(String folderId) async {
    return loadAll(folderId: folderId);
  }

  static Future<List<NoteLink>> getBacklinks(String noteId) async {
    try {
      final response = await ApiClient.dio.get('$_path/$noteId/links');

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data is List ? response.data : [];
        return items.map((item) => NoteLink.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Fehler beim Laden der Links: $e');
    }
  }

  static Future<void> createLink(String sourceNoteId, String targetNoteId) async {
    try {
      await ApiClient.dio.post(
        '$_path/$sourceNoteId/links',
        data: {'targetNoteId': targetNoteId},
      );
    } catch (e) {
      throw Exception('Fehler beim Erstellen des Links: $e');
    }
  }

  static Future<void> deleteLink(String sourceNoteId, String linkId) async {
    try {
      await ApiClient.dio.delete('$_path/$sourceNoteId/links/$linkId');
    } catch (e) {
      throw Exception('Fehler beim Löschen des Links: $e');
    }
  }
}

import 'package:productivity/dataclasses/note_folder.dart';
import 'package:productivity/dataservice/api_client.dart';

class NoteFolderService {
  NoteFolderService._();
  static const String _path = '/note-folders';

  static Future<List<NoteFolder>> loadAll() async {
    try {
      final response = await ApiClient.dio.get(_path);

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data is List ? response.data : [];
        return items.map((item) => NoteFolder.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Fehler beim Laden der Ordner: $e');
    }
  }

  static Future<Map<String, dynamic>> getTree() async {
    try {
      final response = await ApiClient.dio.get('$_path/tree');

      if (response.statusCode == 200) {
        return response.data ?? {};
      }
      return {};
    } catch (e) {
      throw Exception('Fehler beim Laden der Ordnerstruktur: $e');
    }
  }

  static Future<NoteFolder> getById(String id) async {
    try {
      final response = await ApiClient.dio.get('$_path/$id');
      return NoteFolder.fromJson(response.data);
    } catch (e) {
      throw Exception('Fehler beim Laden des Ordners: $e');
    }
  }

  static Future<NoteFolder> create(NoteFolder folder) async {
    try {
      final response = await ApiClient.dio.post(
        _path,
        data: folder.toJson(),
      );
      return NoteFolder.fromJson(response.data);
    } catch (e) {
      throw Exception('Fehler beim Erstellen des Ordners: $e');
    }
  }

  static Future<NoteFolder> update(NoteFolder folder) async {
    try {
      final response = await ApiClient.dio.put(
        '$_path/${folder.id}',
        data: folder.toJson(),
      );
      return NoteFolder.fromJson(response.data);
    } catch (e) {
      throw Exception('Fehler beim Aktualisieren des Ordners: $e');
    }
  }

  static Future<void> delete(String id) async {
    try {
      await ApiClient.dio.delete('$_path/$id');
    } catch (e) {
      throw Exception('Fehler beim Löschen des Ordners: $e');
    }
  }

  static Future<List<NoteFolder>> getRootFolders() async {
    try {
      final folders = await loadAll();
      return folders.where((f) => f.parentFolderId == null).toList();
    } catch (e) {
      throw Exception('Fehler beim Laden der Root-Ordner: $e');
    }
  }
}

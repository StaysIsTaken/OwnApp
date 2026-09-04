import 'package:productivity/dataservice/api_client.dart';

/// Eine Meldung, wie sie die eigene API liefert.
class Meldung {
  final String titel;
  final String text;
  final String ressort;
  final String quelle;
  final DateTime? zeit;

  const Meldung({
    required this.titel,
    this.text = '',
    this.ressort = '',
    this.quelle = '',
    this.zeit,
  });

  factory Meldung.fromJson(Map<String, dynamic> j) => Meldung(
        titel: j['titel']?.toString() ?? '',
        text: j['text']?.toString() ?? '',
        ressort: j['ressort']?.toString() ?? '',
        quelle: j['quelle']?.toString() ?? '',
        zeit: j['zeit'] == null ? null : DateTime.tryParse(j['zeit'].toString()),
      );
}

/// Nachrichten und Sprüche — über die eigene API, nicht direkt vom Anbieter.
///
/// Der Umweg ist Absicht und steht ausführlich im Backend begründet: sonst
/// sähe der Anbieter jede Adresse im Haushalt einzeln, und im Web scheiterte
/// der Aufruf ohnehin an CORS. Zwischengelagert wird ebenfalls dort — hier
/// wird nur geholt.
class FeedService {
  FeedService._();

  static const String _pfad = '/feed';

  static Future<List<Meldung>> nachrichten({int anzahl = 5}) async {
    final r = await ApiClient.dio
        .get('$_pfad/nachrichten', queryParameters: {'anzahl': anzahl});
    final roh = (r.data as Map)['meldungen'] as List<dynamic>? ?? const [];
    return roh
        .map((e) => Meldung.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  static Future<String> witz() async {
    final r = await ApiClient.dio.get('$_pfad/witz');
    return (r.data as Map)['text']?.toString() ?? '';
  }
}

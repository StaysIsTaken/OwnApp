/// Die Stimmerkennung auf der Serverseite: Schalter, Proben, Profile.
///
/// Verglichen wird auf dem Gerät (siehe `stimm_erkennung.dart`). Hier geht
/// es nur darum, was der Server verwahrt.
library;

import 'package:productivity/dataservice/api_client.dart';

/// Was das Gerät wissen muss, bevor es überhaupt vergleicht.
class Stimmeinstellung {
  /// Aus ist der Auslieferungszustand. Stimmen zu erkennen heißt, Stimmen
  /// zu speichern — wer das nicht will, soll es nicht abwählen müssen.
  final bool aktiv;

  /// Ab welcher Ähnlichkeit ein Treffer zählt. Kommt vom Server, damit er
  /// sich ohne neues App-Bündel nachziehen lässt.
  final double schwelle;

  /// Wie viele Proben von mir selbst hinterlegt sind — daran hängt, ob die
  /// Oberfläche „Stimme einlernen" anbietet oder „noch eine Probe".
  final int eigeneProben;

  const Stimmeinstellung({
    required this.aktiv,
    required this.schwelle,
    required this.eigeneProben,
  });

  factory Stimmeinstellung.fromJson(Map<String, dynamic> j) => Stimmeinstellung(
        aktiv: j['aktiv'] == true,
        schwelle: (j['schwelle'] as num?)?.toDouble() ?? 0.6,
        eigeneProben: (j['eigene_proben'] as num?)?.toInt() ?? 0,
      );

  /// Der Zustand, wenn der Server nicht antwortet: nichts tun.
  static const aus = Stimmeinstellung(aktiv: false, schwelle: 0.6, eigeneProben: 0);
}

/// Eine hinterlegte Probe — ohne den Vektor, nur zum Aufräumen.
class Stimmprobe {
  final int id;
  final String userId;
  final String userName;
  final int dim;
  final String? label;

  const Stimmprobe({
    required this.id,
    required this.userId,
    required this.userName,
    required this.dim,
    this.label,
  });

  factory Stimmprobe.fromJson(Map<String, dynamic> j) => Stimmprobe(
        id: (j['id'] as num?)?.toInt() ?? 0,
        userId: j['user_id']?.toString() ?? '',
        userName: j['user_name']?.toString() ?? '?',
        dim: (j['dim'] as num?)?.toInt() ?? 0,
        label: j['label']?.toString(),
      );
}

/// Eine Person mit ihren Vektoren — das, womit das Gerät vergleicht.
class Stimme {
  final String userId;
  final String userName;
  final List<List<double>> embeddings;

  const Stimme({
    required this.userId,
    required this.userName,
    required this.embeddings,
  });

  factory Stimme.fromJson(Map<String, dynamic> j) => Stimme(
        userId: j['user_id']?.toString() ?? '',
        userName: j['user_name']?.toString() ?? '?',
        embeddings: ((j['embeddings'] as List<dynamic>?) ?? const [])
            .map((e) => (e as List<dynamic>)
                .map((x) => (x as num).toDouble())
                .toList())
            .toList(),
      );
}

class StimmService {
  StimmService._();

  static const String _pfad = '/voice';

  static Future<Stimmeinstellung> einstellungen() async {
    final r = await ApiClient.dio.get('$_pfad/einstellungen');
    return Stimmeinstellung.fromJson((r.data as Map).cast<String, dynamic>());
  }

  /// Nur für den Admin (`admin:system`).
  static Future<Stimmeinstellung> setzen({bool? aktiv, double? schwelle}) async {
    final r = await ApiClient.dio.put('$_pfad/einstellungen', data: {
      'aktiv': ?aktiv,
      'schwelle': ?schwelle,
    });
    return Stimmeinstellung.fromJson((r.data as Map).cast<String, dynamic>());
  }

  /// Hinterlegt eine Probe der **eigenen** Stimme.
  ///
  /// Der Nutzer steht nicht im Rumpf — der Server nimmt den aus dem Token.
  /// Eine fremde Probe unter fremdem Namen abzulegen wäre genau der Weg,
  /// die Erkennung zu unterlaufen.
  static Future<Stimmprobe> probeAnlegen(
    List<double> embedding, {
    String? label,
  }) async {
    final r = await ApiClient.dio.post('$_pfad/proben', data: {
      'embedding': embedding,
      'label': ?label,
    });
    return Stimmprobe.fromJson((r.data as Map).cast<String, dynamic>());
  }

  static Future<List<Stimmprobe>> proben({bool alle = false}) async {
    final r = await ApiClient.dio.get(
      '$_pfad/proben',
      queryParameters: alle ? {'alle': true} : null,
    );
    return (r.data as List<dynamic>)
        .map((e) => Stimmprobe.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> probeLoeschen(int id) =>
      ApiClient.dio.delete('$_pfad/proben/$id');

  /// Meine Stimme wieder vergessen — alles auf einmal.
  static Future<int> eigeneVergessen() async {
    final r = await ApiClient.dio.delete('$_pfad/proben');
    return ((r.data as Map)['geloescht'] as num?)?.toInt() ?? 0;
  }

  /// Die Vektoren aller Personen — verlangt `tablet:use`.
  ///
  /// Ist die Erkennung aus, kommt eine leere Liste: dann soll auch nichts
  /// unterwegs sein.
  static Future<List<Stimme>> stimmen() async {
    final r = await ApiClient.dio.get('$_pfad/stimmen');
    return (r.data as List<dynamic>)
        .map((e) => Stimme.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

import 'package:intl/intl.dart';

import 'package:productivity/dataservice/weather_service.dart';

/// Auskünfte, die das Tablet selbst geben kann: Uhrzeit, Datum, Wetter.
///
/// Bewusst ohne Server und ohne Sprachmodell. Ein Umweg über `/assistant/chat`
/// kostete mehrere Sekunden für eine Frage, deren Antwort direkt danebensteht
/// — und ein Sprachmodell weiß die aktuelle Uhrzeit ohnehin nicht: es rät sie
/// aus seinen Trainingsdaten, oft um Stunden daneben und ohne es zu merken.
///
/// Das Wetter kommt aus [WeatherService], also aus derselben Quelle wie die
/// Anzeige auf der Startseite. Zwei Wege zu derselben Zahl wären zwei Wege,
/// die auseinanderlaufen können.
class SprachAuskunft {
  SprachAuskunft._();

  /// Wörter, an denen eine Uhrzeitfrage zu erkennen ist.
  static const List<String> _zeit = [
    'wie spät',
    'wie spaet',
    'wie viel uhr',
    'wieviel uhr',
    'uhrzeit',
    'welche zeit',
  ];

  static const List<String> _datum = [
    'welches datum',
    'welcher tag',
    'welchen tag',
    'was für ein tag',
    'was fuer ein tag',
    'der wievielte',
    'den wievielten',
    'wievielte haben wir',
    'datum haben wir',
  ];

  static const List<String> _wetter = [
    'wetter',
    'regnet',
    'regnen',
    'schneit',
    'sonne scheint',
    'wie warm',
    'wie kalt',
    'temperatur',
    'grad draußen',
    'grad draussen',
  ];

  /// Welche Auskunft gemeint ist, oder null.
  ///
  /// Die Reihenfolge ist nicht beliebig: „wie warm wird es morgen" enthält
  /// kein Zeitwort, aber „wie spät" und „Wetter" könnten in einem Satz
  /// zusammen vorkommen. Wetter zuerst, weil es die spezifischeren Wörter hat.
  static Auskunftsart? erkenne(String text) {
    final t = text.toLowerCase();
    if (_enthaelt(t, _wetter)) return Auskunftsart.wetter;
    if (_enthaelt(t, _zeit)) return Auskunftsart.zeit;
    if (_enthaelt(t, _datum)) return Auskunftsart.datum;
    return null;
  }

  static bool _enthaelt(String text, List<String> woerter) =>
      woerter.any(text.contains);

  /// „Es ist 14 Uhr 30." — gesprochen, nicht abgelesen.
  ///
  /// Bewusst ohne führende Null und ohne Doppelpunkt: „14 Uhr 05" liest die
  /// Sprachausgabe sonst als „vierzehn Uhr null fünf".
  static String zeitAntwort([DateTime? jetzt]) {
    final t = jetzt ?? DateTime.now();
    if (t.minute == 0) return 'Es ist ${t.hour} Uhr.';
    return 'Es ist ${t.hour} Uhr ${t.minute}.';
  }

  /// „Heute ist Donnerstag, der 11. September 2026."
  static String datumAntwort([DateTime? jetzt]) {
    final t = jetzt ?? DateTime.now();
    final tag = DateFormat('EEEE', 'de_DE').format(t);
    final rest = DateFormat("d. MMMM yyyy", 'de_DE').format(t);
    return 'Heute ist $tag, der $rest.';
  }

  /// Holt das Wetter und formt einen Satz daraus.
  ///
  /// [stadt] ist die in den Einstellungen hinterlegte; der Dienst bevorzugt
  /// den Standort, wenn er ihn bekommt.
  static Future<String> wetterAntwort({String? stadt}) async {
    final w = await WeatherService.load(city: stadt);
    if (w == null) return 'Das Wetter bekomme ich gerade nicht.';

    final teile = <String>[];
    if (w.currentTemp != null) {
      final lage = w.currentCode != null ? weatherInfo(w.currentCode!).$2 : '';
      teile.add(lage.isEmpty
          ? 'In ${w.place} sind es ${w.currentTemp!.round()} Grad'
          : 'In ${w.place} sind es ${w.currentTemp!.round()} Grad, $lage');
    }
    if (w.days.isNotEmpty) {
      final heute = w.days.first;
      teile.add('heute zwischen ${heute.tempMin.round()} '
          'und ${heute.tempMax.round()} Grad');
    }
    if (teile.isEmpty) return 'Das Wetter bekomme ich gerade nicht.';
    return '${teile.join(', ')}.';
  }
}

enum Auskunftsart { zeit, datum, wetter }

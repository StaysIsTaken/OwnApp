/// „Jarvis, stell einen Timer für fünf Minuten."
///
/// Wie [SprachAuskunft] und [Sprachbefehle] beantwortet das Tablet diesen
/// Satz selbst — ohne Server, ohne Sprachmodell. Zwei Gründe, dieselben wie
/// dort: der Umweg über `/assistant/chat` kostet Sekunden, und der Server
/// kennt den Timer gar nicht. Der läuft im Gerät.
///
/// Erkannt wird nur, was das Wort „Timer" (oder „Eieruhr") enthält. Das ist
/// Absicht: „wie lange noch" allein ist zu wenig, um daraus einen Befehl zu
/// machen — der Satz kann sich auf alles beziehen, und im Zweifel soll das
/// Modell antworten statt das Gerät.
library;

/// Was mit dem Timer geschehen soll.
enum Timeraktion {
  /// Dauer setzen und loslaufen. Wer eine Zeit nennt, will nicht danach
  /// noch auf „Start" tippen.
  stellen,
  starten,
  pausieren,
  zuruecksetzen,

  /// „Wie lange läuft der Timer noch?"
  restfrage,
}

class Timerbefehl {
  final Timeraktion aktion;

  /// Nur bei [Timeraktion.stellen] gesetzt.
  final Duration? dauer;

  const Timerbefehl(this.aktion, {this.dauer});

  @override
  String toString() => 'Timerbefehl($aktion, $dauer)';

  @override
  bool operator ==(Object other) =>
      other is Timerbefehl && other.aktion == aktion && other.dauer == dauer;

  @override
  int get hashCode => Object.hash(aktion, dauer);
}

class TimerBefehle {
  TimerBefehle._();

  /// Woran ein Timer-Satz zu erkennen ist.
  static const List<String> _anker = ['timer', 'eieruhr', 'küchenuhr', 'kuechenuhr'];

  /// Gesprochene Zahlen. Whisper schreibt „5", wenn jemand deutlich spricht,
  /// und „fünf", wenn nicht — beides muss ankommen.
  static const Map<String, double> _zahlwoerter = {
    'eine': 1, 'einen': 1, 'einem': 1, 'eins': 1, 'ein': 1,
    'zwei': 2, 'zwo': 2, 'drei': 3, 'vier': 4, 'fünf': 5, 'fuenf': 5,
    'sechs': 6, 'sieben': 7, 'acht': 8, 'neun': 9, 'zehn': 10,
    'elf': 11, 'zwölf': 12, 'zwoelf': 12, 'dreizehn': 13, 'vierzehn': 14,
    'fünfzehn': 15, 'fuenfzehn': 15, 'sechzehn': 16, 'siebzehn': 17,
    'achtzehn': 18, 'neunzehn': 19, 'zwanzig': 20,
    'fünfundzwanzig': 25, 'fuenfundzwanzig': 25,
    'dreißig': 30, 'dreissig': 30, 'vierzig': 40,
    'fünfundvierzig': 45, 'fuenfundvierzig': 45,
    'fünfzig': 50, 'fuenfzig': 50, 'sechzig': 60, 'neunzig': 90,
  };

  /// Wendungen, die keine Zahl neben einer Einheit sind, sondern beides in
  /// einem Wort tragen. Werden vor dem Zahlenmuster abgeräumt, sonst läse
  /// „eine halbe Stunde" als „eine Stunde".
  static const Map<String, Duration> _wendungen = {
    'dreiviertelstunde': Duration(minutes: 45),
    'dreiviertel stunde': Duration(minutes: 45),
    'viertelstunde': Duration(minutes: 15),
    'viertel stunde': Duration(minutes: 15),
    'halbe stunde': Duration(minutes: 30),
    'halben stunde': Duration(minutes: 30),
    'anderthalb stunden': Duration(minutes: 90),
    'eineinhalb stunden': Duration(minutes: 90),
  };

  static bool _enthaelt(String text, List<String> woerter) =>
      woerter.any(text.contains);

  /// Summiert alle Zahl-Einheit-Paare im Satz.
  ///
  /// Mehrere Paare werden addiert, damit „eine Stunde und zwanzig Minuten"
  /// nicht auf die Stunde zusammenfällt. Rückgabe null, wenn gar keine
  /// Dauer dasteht — dann ist es kein Stell-Befehl.
  static Duration? dauerAus(String roh) {
    var text = roh.toLowerCase();
    var gesamt = Duration.zero;
    var gefunden = false;

    // Längste Wendung zuerst: „dreiviertelstunde" enthält „viertelstunde".
    final wendungen = _wendungen.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final wendung in wendungen) {
      while (text.contains(wendung)) {
        gesamt += _wendungen[wendung]!;
        gefunden = true;
        text = text.replaceFirst(wendung, ' ');
      }
    }

    // Längstes Zahlwort zuerst. Eindeutig wäre es auch ohne: hinter der
    // Zahl muss eine Einheit stehen, und „fünf" gefolgt von „undvierzig"
    // erfüllt das nicht — die Regex fiele zurück. Die Sortierung erspart
    // ihr dieses Zurückfallen.
    final zahlen = _zahlwoerter.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final muster = RegExp(
      '(\\d+(?:[.,]\\d+)?|${zahlen.join('|')})\\s*'
      r'(stunden|stunde|std|minuten|minute|min|sekunden|sekunde|sek)\b',
    );

    for (final treffer in muster.allMatches(text)) {
      final wert = _zahlAus(treffer.group(1)!);
      if (wert == null) continue;
      final einheit = treffer.group(2)!;
      final proEinheit = einheit.startsWith('st')
          ? 3600
          : einheit.startsWith('min')
              ? 60
              : 1;
      gesamt += Duration(seconds: (wert * proEinheit).round());
      gefunden = true;
    }

    if (!gefunden || gesamt <= Duration.zero) return null;
    return gesamt;
  }

  static double? _zahlAus(String roh) {
    final wort = _zahlwoerter[roh];
    if (wort != null) return wort;
    // „1,5 Stunden" — im Deutschen ist das Komma das Trennzeichen.
    return double.tryParse(roh.replaceAll(',', '.'));
  }

  /// Erkennt einen Timer-Befehl, oder null wenn der Satz keiner ist.
  static Timerbefehl? erkenne(String roh) {
    final text = roh.toLowerCase();
    if (!_enthaelt(text, _anker)) return null;

    // Eine genannte Dauer schlägt alles andere: „stell den Timer auf drei
    // Minuten" ist ein Stellen, auch wenn „stell" für sich nichts sagt.
    final dauer = dauerAus(text);
    if (dauer != null) return Timerbefehl(Timeraktion.stellen, dauer: dauer);

    // Anhalten vor Starten: „stopp" und „starte" kommen beide vor, aber wer
    // „stopp" sagt, meint nie „start".
    // 'halt' statt 'halt an': dazwischen steht meist das Objekt — „halt
    // den Timer an". Weil ohnehin „Timer" im Satz stehen muss, faengt
    // das kurze Wort hier nichts Fremdes.
    if (_enthaelt(text, ['stopp', 'stop', 'halt', 'pausier', 'pause'])) {
      return const Timerbefehl(Timeraktion.pausieren);
    }
    if (_enthaelt(text, ['zurücksetz', 'zuruecksetz', 'zurück setz', 'abbrechen',
                         'brich ab', 'lösch', 'loesch', 'weg damit'])) {
      return const Timerbefehl(Timeraktion.zuruecksetzen);
    }
    if (_enthaelt(text, ['wie lange', 'wie lang', 'wie viel', 'wieviel', 'rest'])) {
      return const Timerbefehl(Timeraktion.restfrage);
    }
    if (_enthaelt(text, ['start', 'lauf', 'los', 'weiter'])) {
      return const Timerbefehl(Timeraktion.starten);
    }
    return null;
  }
}

/// Eine Dauer so, wie man sie sagt.
///
/// Nicht `dauerText` aus der Uhrkachel: „05:00" vorgelesen wird zu „null
/// fünf null null". Was man hört, soll „fünf Minuten" sein.
///
/// Der Einer bekommt seine eigene Form — „1 Minuten" verrät die Maschine
/// deutlicher als jede Stimme.
String dauerSprache(Duration d) {
  if (d <= Duration.zero) return 'null';

  final stunden = d.inHours;
  final minuten = d.inMinutes.remainder(60);
  final sekunden = d.inSeconds.remainder(60);

  String teil(int wert, String einzahl, String mehrzahl) =>
      wert == 1 ? 'eine $einzahl' : '$wert $mehrzahl';

  final teile = <String>[
    if (stunden > 0)
      stunden == 1 ? 'eine Stunde' : '$stunden Stunden',
    if (minuten > 0) teil(minuten, 'Minute', 'Minuten'),
    // Sekunden nur nennen, wenn sie etwas beitragen: „fünf Minuten und null
    // Sekunden" sagt niemand.
    if (sekunden > 0) teil(sekunden, 'Sekunde', 'Sekunden'),
  ];

  if (teile.length == 1) return teile.first;
  return '${teile.sublist(0, teile.length - 1).join(', ')} und ${teile.last}';
}

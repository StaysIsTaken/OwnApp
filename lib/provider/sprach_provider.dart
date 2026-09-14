import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'package:productivity/dataservice/assistant_service.dart';
import 'package:productivity/dataservice/kalender_filter.dart';
import 'package:productivity/dataservice/sprach_auskunft.dart';
import 'package:productivity/dataclasses/einkauf.dart';
import 'package:productivity/dataservice/einkauf_service.dart';
import 'package:productivity/dataservice/listen_befehle.dart';
import 'package:productivity/dataservice/timer_befehle.dart';
import 'package:productivity/dataservice/sprachbefehle.dart';
import 'package:productivity/dataservice/transcription_service.dart';
import 'package:productivity/dataservice/tts_service.dart';
import 'package:productivity/dataservice/wakeword_service.dart';
import 'package:productivity/dataservice/wakeword_ton.dart';
import 'package:productivity/provider/planner_provider.dart';
import 'package:productivity/provider/tablet_seiten_provider.dart';
import 'package:productivity/provider/timer_provider.dart';

enum SprachZustand { ruht, hoert, denkt, spricht }

/// Was mit einer laufenden Aufnahme geschehen soll.
enum Aufnahmeschritt {
  /// Weiter aufnehmen.
  weiter,

  /// Satz zu Ende — aufnehmen, hochladen, verstehen.
  beenden,

  /// Es hat nie jemand angefangen zu reden. Verwerfen statt hochladen.
  nichtsGehoert,
}

/// Der Sprach-Ablauf des Küchentablets: aufnehmen, verstehen, ausführen,
/// antworten.
///
/// Zwei Wege hinein, danach derselbe Ablauf: der Knopf auf dem Dashboard und
/// das Weckwort „Jarvis". Beide rufen [starten].
///
/// Der heikle Teil ist die Mikrofon-Übergabe. Die Weckworterkennung hält den
/// Audiostrom, solange sie lauscht; der Rekorder braucht ihn exklusiv. Deshalb
/// genau eine Reihenfolge, und sie steht in [starten] und [_zurueckInRuhe]:
///
///     Weckwort -> Erkenner anhalten -> aufnehmen -> verstehen -> ausführen
///     -> sprechen -> Erkenner fortsetzen
///
/// Das Fortsetzen liegt bewusst am gemeinsamen Rückweg und nicht am Ende des
/// Erfolgsfalls: sonst wäre Jarvis nach dem ersten Fehler dauerhaft taub.
class SprachProvider extends ChangeNotifier {
  SprachProvider(this._seiten, this._planer, this._timer);

  final TabletSeitenProvider _seiten;

  /// Die Eieruhr. Liegt app-weit, nicht in der Uhrkachel — sonst liesse
  /// sie sich nur stellen, solange man genau davorsteht.
  final TimerProvider _timer;

  /// Was zuletzt zur Auswahl stand („welche Liste?").
  ///
  /// Ohne das endet die Rückfrage in einer Sackgasse: die einzige Antwort,
  /// die ankäme, wäre der vollständige Name.
  final Listengedaechtnis _listen = Listengedaechtnis();

  @visibleForTesting
  Listengedaechtnis get listengedaechtnis => _listen;

  /// Nur für „zeige nur … Kalender an". Der Filter sitzt im Planer, weil
  /// dort die Termine liegen — die Kalenderansicht auf einer Kachel und die
  /// im Menü sollen dasselbe zeigen.
  final PlannerProvider _planer;

  // ── Schwellen der Stille-Erkennung ────────────────────────────────────
  // Die Werte sind in dBFS (0 = Vollausschlag, Stille weit im Negativen) und
  // hängen am Mikrofon des Geräts. Auf dem Tab A8 mit seinem einzelnen
  // Mikrofon dürfen sie eher empfindlich sein; in einer lauten Küche muss
  // _schwelleStimme womöglich höher.
  static const double _schwelleStimme = -32.0;

  /// So viele laute Messungen hintereinander gelten als Sprache. Der
  /// Pegelstrom kommt alle 200 ms, zwei sind also gut 400 ms. Ein einzelner
  /// Ausschlag -- ein Pling, ein Türklappen -- reicht bewusst nicht.
  static const int _lauteFuerSprache = 2;

  /// Vor Ablauf dieser Zeit endet keine Aufnahme, egal wie still es ist.
  /// Nach dem Weckwort überlegt man kurz, und das darf kein Satzende sein.
  static const Duration _mindestdauer = Duration(milliseconds: 2500);

  static const Duration _stillePause = Duration(milliseconds: 1500);
  static const Duration _maxVorlauf = Duration(seconds: 6);
  static const Duration _maxGesamt = Duration(seconds: 15);

  /// Am Anfang der Aufnahme werden Pegel ignoriert.
  ///
  /// Sonst zählt das Bestätigungs-Pling als Sprache: die Stille-Uhr liefe ab
  /// dem Ton, und wer nach „Hey Jarvis" eine Sekunde überlegt, würde
  /// abgeschnitten, bevor er den Satz beginnt. Dasselbe gilt für das
  /// Nachklingen des Weckworts selbst.
  static const Duration _blindzeit = Duration(milliseconds: 600);

  /// Aktionen, die per Sprache ohne Rückfrage ausgeführt werden. Alles hier
  /// legt etwas an oder ändert eine Menge — im Zweifel steht ein Posten zu
  /// viel auf der Einkaufsliste, und den streicht man in zwei Sekunden.
  ///
  /// Was löscht, steht bewusst NICHT hier: `delete_planner_entry` und
  /// `remove_shopping_item` will man nicht auf ein missverstandenes Wort hin
  /// ausgeführt bekommen.
  static const Set<String> _ohneRueckfrage = {
    'add_shopping_item',
    'update_shopping_item',
    // Dieselben zwei auf dem neuen Listenmodell. Ohne sie hier braeuchte
    // „setz Milch auf die Liste" ploetzlich wieder einen Fingertipp.
    'add_shopping_position',
    'update_shopping_position',
    'add_pantry_item',
    'update_pantry_item',
    'create_planner_entry',
    'create_subtask',
    'create_note',
    'create_journal_entry',
  };

  /// Wie viele Nachrichten Verlauf mitgeschickt werden. Genug für ein „und
  /// noch Butter dazu", wenig genug, dass das Modell nicht bei jedem Zuruf
  /// den halben Vormittag mitliest.
  static const int _verlaufLaenge = 6;

  /// Wie oft Jarvis je Zuruf zurückfragen darf.
  ///
  /// Zwei reichen für „in welchen Kalender?" und eine Nachfrage, falls die
  /// Antwort unklar war. Ohne Grenze könnten sich Modell und Mikrofon
  /// gegenseitig am Leben halten, bis jemand eingreift.
  static const int _maxRueckfragen = 2;

  SprachZustand _zustand = SprachZustand.ruht;
  String _verstanden = '';
  String _antwort = '';
  String? _fehler;
  final List<Map<String, String>> _verlauf = [];
  final List<AssistantPendingAction> _offen = [];

  StreamSubscription<Amplitude>? _pegelAbo;
  DateTime? _begonnen;
  DateTime? _letzteStimme;
  bool _hatGesprochen = false;
  int _lauteHintereinander = 0;
  bool _beendet = false;

  /// Wie oft in diesem Zuruf schon zurückgefragt wurde.
  int _rueckfragen = 0;

  /// Gesetzt, sobald der Nutzer abbricht. Die schon laufende Verarbeitung
  /// lässt sich nicht zurückrufen — aber sie darf danach nicht mehr reden.
  bool _abgebrochen = false;

  bool _wakewordAn = false;
  bool _wakewordLaeuft = false;
  String? _wakewordFehler;

  /// Die in den Einstellungen hinterlegte Stadt, fürs Wetter. Wird vom
  /// Dashboard nachgeführt — der Sprach-Ablauf soll die Einstellungen nicht
  /// selbst kennen müssen, sonst hinge er an einem zweiten Provider.
  String? wetterStadt;
  String? get _wetterStadt => wetterStadt;

  /// Ob auf „Jarvis" gelauscht werden soll (Einstellung).
  bool get wakewordAn => _wakewordAn;

  /// Ob tatsächlich gelauscht wird. Weicht von [wakewordAn] ab, während
  /// gerade aufgenommen oder gesprochen wird — dann hat das Mikrofon einen
  /// anderen Besitzer.
  bool get wakewordLaeuft => _wakewordLaeuft;

  String? get wakewordFehler => _wakewordFehler;

  SprachZustand get zustand => _zustand;
  String get verstanden => _verstanden;
  String get antwort => _antwort;
  String? get fehler => _fehler;
  bool get aktiv => _zustand != SprachZustand.ruht;

  /// Aktionen, die eine Bestätigung per Tipp brauchen.
  List<AssistantPendingAction> get offeneAktionen => List.unmodifiable(_offen);

  void _setze(SprachZustand z) {
    _zustand = z;
    notifyListeners();
  }

  /// Zurück in den Ruhezustand — und dabei das Mikrofon an Porcupine
  /// zurückgeben.
  ///
  /// Jeder Weg zurück nach `ruht` führt hierdurch, auch der über einen
  /// Fehler. Ein `fortsetzen`, das nur im Erfolgsfall käme, hieße: der erste
  /// Aussetzer macht Jarvis für immer taub.
  void _zurueckInRuhe() {
    _setze(SprachZustand.ruht);
    if (_wakewordAn) unawaited(_wakewordFortsetzen());
  }

  Future<void> _wakewordFortsetzen() async {
    try {
      await WakewordService.fortsetzen();
      _wakewordLaeuft = WakewordService.laeuft;
    } catch (e) {
      _wakewordLaeuft = false;
      _wakewordFehler = WakewordService.erklaere(e);
    }
    notifyListeners();
  }

  /// Startet eine Aufnahme. Sie endet von selbst, sobald du aufhörst zu reden.
  ///
  /// [mitTon] bestätigt hörbar, dass zugehört wird — beim Zuruf über das
  /// Weckwort steht man nicht vor dem Bildschirm. Beim Tastendruck erübrigt
  /// sich das, da sieht man den Knopf ja umspringen.
  Future<void> starten({bool mitTon = false}) async {
    if (aktiv) return;
    _rueckfragen = 0;
    _offen.clear();
    await _hoerZu(mitTon: mitTon);
  }

  /// Hört zu — ohne die Frage, ob das gerade erlaubt ist.
  ///
  /// Getrennt von [starten], weil die Rückfrage sie aus dem Zustand
  /// `spricht` heraus aufruft: dort ist [aktiv] wahr, und die Sperre in
  /// [starten] würde das Weiterhören verhindern.
  Future<void> _hoerZu({required bool mitTon}) async {
    _verstanden = '';
    _antwort = '';
    _fehler = null;
    _hatGesprochen = false;
    _lauteHintereinander = 0;
    _beendet = false;
    _abgebrochen = false;

    try {
      if (!await TranscriptionService.hasPermission()) {
        _abbrechenMit('Kein Mikrofon-Zugriff erlaubt.');
        return;
      }
      await TtsService.stopp(); // Nicht gegen die eigene Stimme aufnehmen.
      // Das Mikrofon gehört immer nur einem: Porcupine muss los, bevor der
      // Rekorder es greifen kann.
      await WakewordService.anhalten();
      await _aufnahmeStarten();
      // Zusammen mit der Aufnahme, nicht davor: 200 ms Warten auf das Pling
      // würden das erste Wort abschneiden. Dass der Ton mit aufgenommen wird,
      // fängt die _blindzeit ab.
      if (mitTon) unawaited(WakewordTon.spielen());
    } catch (e) {
      _abbrechenMit('Aufnahme fehlgeschlagen: $e');
      return;
    }

    _begonnen = DateTime.now();
    _letzteStimme = _begonnen;
    _setze(SprachZustand.hoert);

    _pegelAbo = TranscriptionService.pegel().listen(
      _pegelGesehen,
      onError: (_) {
        // Ohne Pegelwerte gibt es keine Stille-Erkennung mehr. Die Aufnahme
        // läuft weiter und endet per Hand oder spätestens über _maxGesamt.
      },
    );
  }

  /// Aufnahme starten, mit einem zweiten Versuch.
  ///
  /// Porcupine gibt das Mikrofon beim Anhalten frei, aber Android braucht
  /// dafür je nach Gerät einen Moment. Greift der Rekorder in genau diese
  /// Lücke, scheitert er — und der Zuruf wäre verloren, obwohl 150 ms später
  /// alles bereit ist. Nur ein Wiederholungsversuch: hakt es dauerhaft, ist
  /// es kein Zeitproblem, und dann soll der Fehler auch sichtbar werden.
  Future<void> _aufnahmeStarten() async {
    try {
      await TranscriptionService.start();
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 150));
      await TranscriptionService.start();
    }
  }

  void _pegelGesehen(Amplitude amp) {
    if (_beendet || _begonnen == null) return;
    final jetzt = DateTime.now();
    final seitStart = jetzt.difference(_begonnen!);

    if (seitStart >= _blindzeit) {
      if (amp.current > _schwelleStimme) {
        _lauteHintereinander++;
        _letzteStimme = jetzt;
      } else {
        _lauteHintereinander = 0;
      }
      // Erst mehrere laute Messungen hintereinander gelten als Sprache.
      //
      // Vorher genügte eine einzige, und das war der Fehler: das
      // Bestätigungs-Pling reichte, um die Stille-Uhr zu starten. Wer danach
      // kurz überlegte, dessen Aufnahme war vorbei, bevor das erste Wort
      // gesagt war -- und Whisper bekam nichts als den Ton.
      if (_lauteHintereinander >= _lauteFuerSprache) _hatGesprochen = true;
    }

    switch (entscheide(
      seitStart: seitStart,
      seitLetzterStimme: jetzt.difference(_letzteStimme!),
      hatGesprochen: _hatGesprochen,
    )) {
      case Aufnahmeschritt.weiter:
        break;
      case Aufnahmeschritt.nichtsGehoert:
        _beenden(nichtsGehoert: true);
      case Aufnahmeschritt.beenden:
        _beenden();
    }
  }

  /// Wann eine laufende Aufnahme endet — als reine Rechnung, ohne Mikrofon
  /// und ohne Uhr.
  ///
  /// Bewusst herausgezogen: die Entscheidung steckte vorher mitten im
  /// Pegelstrom und war damit nur auf einem Gerät zu prüfen. Genau dort saß
  /// der Fehler, der die Aufnahme nach dem Weckwort zu früh beendete.
  @visibleForTesting
  static Aufnahmeschritt entscheide({
    required Duration seitStart,
    required Duration seitLetzterStimme,
    required bool hatGesprochen,
  }) {
    if (seitStart < _blindzeit) return Aufnahmeschritt.weiter;

    if (!hatGesprochen) {
      // Es hat nie jemand angefangen zu reden -> nicht endlos mitlaufen.
      return seitStart > _maxVorlauf
          ? Aufnahmeschritt.nichtsGehoert
          : Aufnahmeschritt.weiter;
    }

    // Nie vor der Mindestdauer abbrechen. Ein kurzes Wort, dann eine
    // Atempause — das ist normales Sprechen und kein Satzende.
    if (seitStart < _mindestdauer) return Aufnahmeschritt.weiter;

    if (seitLetzterStimme > _stillePause || seitStart > _maxGesamt) {
      return Aufnahmeschritt.beenden;
    }
    return Aufnahmeschritt.weiter;
  }

  /// Schaltet das Lauschen auf „Jarvis" ein.
  ///
  /// [schwelle] ist die Empfindlichkeit: kleiner heißt, dass Jarvis schon bei
  /// undeutlicher Aussprache anspringt — und öfter beim Fernseher.
  ///
  /// Fehler landen in [wakewordFehler] statt zu fliegen: ein fehlendes Modell
  /// oder ein verweigertes Mikrofon darf die Küchenansicht nicht verhindern —
  /// man bedient sie dann eben per Knopf, und der Grund steht daneben.
  Future<void> wakewordEinschalten({double schwelle = 0.25}) async {
    if (_wakewordAn && WakewordService.bereit) return;
    _wakewordAn = true;
    _wakewordFehler = null;
    try {
      await WakewordService.starten(
        schwelle: schwelle,
        beiWakeword: () {
          // Nur wecken, wenn gerade nichts läuft. Ein „Jarvis" mitten in der
          // Antwort soll nicht mitten hinein eine zweite Aufnahme starten.
          if (!aktiv) unawaited(starten(mitTon: true));
        },
        beiFehler: (meldung) {
          _wakewordLaeuft = false;
          _wakewordFehler = meldung;
          notifyListeners();
        },
      );
      _wakewordLaeuft = WakewordService.laeuft;
    } catch (e) {
      _wakewordAn = false;
      _wakewordLaeuft = false;
      _wakewordFehler = WakewordService.erklaere(e);
    }
    notifyListeners();
  }

  Future<void> wakewordAusschalten() async {
    _wakewordAn = false;
    _wakewordLaeuft = false;
    await WakewordService.beenden();
    notifyListeners();
  }

  /// Von Hand beenden — für den Fall, dass die Stille-Erkennung danebenliegt.
  Future<void> jetztStoppen() async {
    if (_zustand == SprachZustand.hoert) await _beenden();
  }

  /// Alles abbrechen und verwerfen.
  Future<void> abbrechen() async {
    await _pegelAbo?.cancel();
    _pegelAbo = null;
    _beendet = true;
    _abgebrochen = true;
    await TranscriptionService.cancel();
    await TtsService.stopp();
    _zurueckInRuhe();
  }

  Future<void> _beenden({bool nichtsGehoert = false}) async {
    if (_beendet) return;
    _beendet = true;
    await _pegelAbo?.cancel();
    _pegelAbo = null;

    if (nichtsGehoert) {
      await TranscriptionService.cancel();
      _abbrechenMit('Nichts gehört.');
      return;
    }

    _setze(SprachZustand.denkt);
    try {
      final text = await TranscriptionService.stopAndTranscribe(
        language: 'de',
        // Kurze Zurufe brauchen kein großes Modell; das kleine antwortet
        // schneller und liegt bei „Milch auf die Einkaufsliste" genauso
        // richtig.
        model: 'small',
      );
      _verstanden = text.trim();
      notifyListeners();

      if (_verstanden.isEmpty) {
        _abbrechenMit('Nichts verstanden.');
        return;
      }
      await _verarbeite(_verstanden);
    } catch (e) {
      _abbrechenMit('Hat nicht geklappt: $e');
    }
  }

  Future<void> _verarbeite(String text) async {
    // Die Kalenderauswahl steht vor allem anderen, weil sie mit demselben
    // Wort anfängt wie ein Seitenwechsel: „zeige nur den Arbeitskalender an"
    // wäre sonst die Suche nach einer Seite dieses Namens.
    if (await _kalenderAuswahl(text)) return;

    // Zuerst das, was das Tablet selbst kann — ohne Netz, ohne Modell.
    final ziel = Sprachbefehle.navigationsZiel(text);
    if (ziel != null) {
      final treffer = _seiten.wechsleNach(ziel);
      if (treffer != null) {
        await _antworte(treffer);
        return;
      }
      // Eine Einleitung war da, die Seite gibt es nicht. Das ist eher ein
      // Verhörer als eine Frage ans Modell — sag es und hör auf.
      await _antworte('Die Seite $ziel kenne ich nicht.');
      return;
    }

    // Der Timer ebenfalls: er läuft im Gerät, der Server weiß nichts von
    // ihm, und „stell einen Timer für fünf Minuten" soll sofort losgehen.
    final timerbefehl = TimerBefehle.erkenne(text);
    if (timerbefehl != null) {
      await _antworte(_timerAusfuehren(timerbefehl));
      return;
    }

    // Eine Antwort auf „welche Liste?" — vor allem anderen, denn „die
    // zweite" ist für sich genommen kein Satz, mit dem irgendetwas
    // anzufangen wäre.
    if (await _listenauswahl(text)) return;

    // Die Einkaufsliste liest das Gerät selbst vor. Das Modell würde sie
    // nacherzählen: Posten zusammenfassen, umsortieren, weglassen. Wer
    // eine Einkaufsliste hört, will sie vollständig und der Reihe nach.
    if (ListenBefehle.istVorlesen(text)) {
      await _vorlesen();
      return;
    }

    // Uhrzeit, Datum, Wetter weiß das Gerät selbst. Der Umweg über das Modell
    // kostete Sekunden für eine Antwort, die danebensteht — und die Uhrzeit
    // rät ein Sprachmodell ohnehin nur.
    final auskunft = SprachAuskunft.erkenne(text);
    if (auskunft != null) {
      await _antworte(switch (auskunft) {
        Auskunftsart.zeit => SprachAuskunft.zeitAntwort(),
        Auskunftsart.datum => SprachAuskunft.datumAntwort(),
        Auskunftsart.wetter =>
          await SprachAuskunft.wetterAntwort(stadt: _wetterStadt),
      });
      return;
    }

    _verlauf.add({'role': 'user', 'content': text});
    while (_verlauf.length > _verlaufLaenge) {
      _verlauf.removeAt(0);
    }

    final ergebnis = await AssistantService.chat(messages: List.of(_verlauf));
    _verlauf.add({'role': 'assistant', 'content': ergebnis.reply});
    // Wer währenddessen abgebrochen hat, will auch nicht, dass jetzt noch
    // etwas eingetragen wird.
    if (_abgebrochen) return;

    final erledigt = <String>[];
    var etwasGetan = false;
    for (final aktion in ergebnis.pendingActions) {
      if (!_ohneRueckfrage.contains(aktion.kind)) {
        _offen.add(aktion);
        continue;
      }
      try {
        await AssistantService.execute(aktion.kind, aktion.params);
        erledigt.add(aktion.label);
        etwasGetan = true;
      } catch (e) {
        _fehler = 'Konnte "${aktion.label}" nicht ausführen: $e';
      }
    }
    if (etwasGetan) _seiten.neuLaden();

    // Was ausgeführt wurde, wird vorgelesen — nicht die Erzählung des Modells
    // darüber. Wer zuruft, will die Bestätigung hören, nicht die Begründung.
    final teile = <String>[
      if (erledigt.isNotEmpty) erledigt.join('. '),
      if (erledigt.isEmpty && ergebnis.reply.trim().isNotEmpty)
        ergebnis.reply.trim(),
      if (_offen.isNotEmpty)
        _offen.length == 1
            ? 'Eine Sache wartet auf deine Bestätigung.'
            : '${_offen.length} Sachen warten auf deine Bestätigung.',
      ?_fehler,
    ];

    // „In welchen Kalender soll ich es eintragen?" — darauf will der Nutzer
    // sofort antworten können, nicht erst wieder „Hey Jarvis" sagen müssen.
    // Nur wenn wirklich nichts passiert ist: eine offene Bestätigung wartet
    // auf einen Tipp, nicht auf ein Wort.
    await _antworte(
      teile.join(' '),
      weiterhoeren: istRueckfrage(
        ergebnis.reply,
        etwasGetan: etwasGetan || _offen.isNotEmpty,
      ),
    );
  }

  /// Führt den Timer-Befehl aus und liefert, was vorgelesen wird.
  ///
  /// Die Antwort nennt immer die Zeit, nicht nur „erledigt": wer quer durch
  /// die Küche zuruft, hört sonst nicht, ob die fünf Minuten oder fünfzehn
  /// geworden sind.
  String _timerAusfuehren(Timerbefehl befehl) {
    switch (befehl.aktion) {
      case Timeraktion.stellen:
        _timer.stelleUndStarte(befehl.dauer!);
        return 'Timer läuft: ${dauerSprache(befehl.dauer!)}.';
      case Timeraktion.starten:
        if (_timer.laeuft) return 'Der Timer läuft schon.';
        _timer.starten();
        return 'Timer läuft: ${dauerSprache(_timer.rest)}.';
      case Timeraktion.pausieren:
        if (!_timer.laeuft) return 'Der Timer läuft gerade nicht.';
        _timer.pausieren();
        return 'Timer angehalten bei ${dauerSprache(_timer.rest)}.';
      case Timeraktion.zuruecksetzen:
        _timer.zuruecksetzen();
        return 'Timer zurückgesetzt auf ${dauerSprache(_timer.gestellt)}.';
      case Timeraktion.restfrage:
        if (_timer.laeuft) {
          return 'Noch ${dauerSprache(_timer.rest)}.';
        }
        if (_timer.abgelaufen) return 'Der Timer ist abgelaufen.';
        return 'Der Timer läuft gerade nicht. '
            'Gestellt ist er auf ${dauerSprache(_timer.gestellt)}.';
    }
  }

  /// Liest die Einkaufsliste vor.
  ///
  /// Gibt es mehrere, wird gefragt — und die Antwort darauf fängt
  /// [_listenauswahl] ab.
  Future<void> _vorlesen({String? name}) async {
    List<Einkaufsliste> listen;
    try {
      listen = await EinkaufService.listen();
    } catch (e) {
      await _antworte('Ich komme gerade nicht an die Listen.');
      return;
    }

    if (listen.isEmpty) {
      await _antworte('Es gibt noch keine Einkaufsliste.');
      return;
    }

    var gemeint = listen.first;
    if (name != null) {
      gemeint = listen.firstWhere((l) => l.name == name,
          orElse: () => listen.first);
    } else if (listen.length > 1) {
      // Merken, BEVOR gefragt wird: die Antwort kommt sofort danach, und
      // ohne das Gemerkte wäre sie nicht zu deuten.
      _listen.merken([for (final l in listen) l.name]);
      await _antworte(
        'Welche Liste? ${_aufzaehlung([for (final l in listen) l.name])}.',
        weiterhoeren: true,
      );
      return;
    }

    _listen.vergessen();
    List<Einkaufsposition> positionen;
    try {
      positionen = await EinkaufService.positionen(gemeint.id);
    } catch (e) {
      await _antworte('Ich komme gerade nicht an „${gemeint.name}".');
      return;
    }

    // Nur das Offene: was abgehakt ist, muss niemand mehr kaufen.
    final offen = positionen.where((p) => !p.erledigt).toList();
    if (offen.isEmpty) {
      await _antworte('Auf „${gemeint.name}" steht nichts mehr.');
      return;
    }

    // Mit Menge, wo eine dasteht — „zwei Milch" ist etwas anderes als
    // „Milch".
    final teile = [
      for (final p in offen)
        p.menge == null || p.menge == 1
            ? p.name
            : '${p.menge! % 1 == 0 ? p.menge!.toInt() : p.menge} ${p.name}',
    ];
    await _antworte(
      offen.length == 1
          ? 'Auf „${gemeint.name}" steht nur ${teile.first}.'
          : '„${gemeint.name}", ${offen.length} Posten: '
              '${_aufzaehlung(teile)}.',
    );
  }

  /// Fängt „die zweite" oder „die vom Baumarkt" ab.
  ///
  /// Liefert true, wenn der Satz eine Antwort auf eine offene Rückfrage
  /// war — dann ist der Ablauf hier zu Ende und geht nicht ans Modell.
  Future<bool> _listenauswahl(String text) async {
    final gewaehlt = _listen.aufloesen(text);
    if (gewaehlt == null) return false;
    _listen.vergessen();
    await _vorlesen(name: gewaehlt);
    return true;
  }

  /// „Zeige nur den Arbeitskalender und Lisas Kalender an.""
  ///
  /// Liefert true, wenn der Satz eine Kalenderauswahl war und beantwortet
  /// wurde — dann ist der Ablauf hier zu Ende.
  Future<bool> _kalenderAuswahl(String text) async {
    final namen = KalenderFilter.erkenne(text);
    if (namen == null) return false;

    if (namen.isEmpty) {
      _planer.zeigeNur(null);
      await _antworte('Ich zeige wieder alle Kalender.');
      return true;
    }

    // Erst jetzt holen: solange niemand filtert, braucht das Tablet die
    // Liste nicht.
    if (_planer.kalender.isEmpty) {
      await _planer.loadKalender(alle: true);
    }

    final ids = KalenderFilter.waehle(_planer.kalender, namen);
    if (ids.isEmpty) {
      await _antworte(
        namen.length == 1
            ? 'Einen Kalender ${namen.first} finde ich nicht.'
            : 'Diese Kalender finde ich nicht.',
      );
      return true;
    }

    _planer.zeigeNur(ids);
    await _antworte('Ich zeige nur noch ${_aufzaehlung(_planer.sichtbareNamen)}.');
    return true;
  }

  /// „a, b und c" — mit „und" vor dem letzten, weil es vorgelesen wird.
  @visibleForTesting
  static String aufzaehlung(List<String> teile) => _aufzaehlung(teile);

  static String _aufzaehlung(List<String> teile) {
    if (teile.isEmpty) return 'nichts';
    if (teile.length == 1) return teile.first;
    return '${teile.sublist(0, teile.length - 1).join(', ')} und ${teile.last}';
  }

  /// Führt eine zurückgestellte Aktion nach einem Tipp doch aus.
  Future<void> bestaetige(AssistantPendingAction aktion) async {
    try {
      await AssistantService.execute(aktion.kind, aktion.params);
      _offen.remove(aktion);
      _seiten.neuLaden();
      notifyListeners();
      await TtsService.sprich(aktion.label);
    } catch (e) {
      _fehler = 'Konnte "${aktion.label}" nicht ausführen: $e';
      notifyListeners();
    }
  }

  void verwerfe(AssistantPendingAction aktion) {
    _offen.remove(aktion);
    notifyListeners();
  }

  Future<void> _antworte(String text, {bool weiterhoeren = false}) async {
    if (_abgebrochen) return;
    _antwort = text.trim();
    _setze(SprachZustand.spricht);
    await TtsService.sprich(_antwort);

    // Nach dem Abbruch ist der Zustand schon zurückgesetzt; ihn hier noch
    // einmal zu setzen würde die Anzeige aus einem Ablauf überschreiben, den
    // niemand mehr sehen will.
    if (_abgebrochen) return;

    // Hat Jarvis gefragt, hört er gleich weiter zu. Sonst müsste man nach
    // seiner Rückfrage erneut „Hey Jarvis" sagen, um zu antworten — das ist
    // kein Gespräch, das ist ein Formular.
    if (weiterhoeren && _rueckfragen < _maxRueckfragen) {
      _rueckfragen++;
      // Mit Ton: nach einer Frage ist das Pling die einzige Rückmeldung,
      // dass er die Antwort abwartet.
      await _hoerZu(mitTon: true);
      return;
    }
    _zurueckInRuhe();
  }

  /// Ob die Antwort eine Rückfrage ist, auf die der Nutzer antworten soll.
  ///
  /// Zwei Bedingungen, und die zweite ist die wichtigere: es muss ein
  /// Fragezeichen am Ende stehen UND nichts passiert sein. „Eingetragen.
  /// Noch etwas?" ist Höflichkeit, keine Rückfrage — wer darauf zu lauschen
  /// begänne, hielte das Mikrofon nach jedem Auftrag unnötig offen.
  @visibleForTesting
  static bool istRueckfrage(String antwort, {required bool etwasGetan}) {
    if (etwasGetan) return false;
    return antwort.trimRight().endsWith('?');
  }

  void _abbrechenMit(String meldung) {
    _fehler = meldung;
    _zurueckInRuhe();
    // Kurz genug, um sie zu sagen statt sie nur anzuzeigen: wer quer durch die
    // Küche ruft, schaut nicht auf den Bildschirm.
    unawaited(TtsService.sprich(meldung));
  }

  @override
  void dispose() {
    _pegelAbo?.cancel();
    TtsService.stopp();
    // Ganz freigeben, nicht nur anhalten: wer die Küchenansicht verlässt,
    // trägt das Gerät womöglich in der Hand aus dem Raum.
    unawaited(WakewordService.beenden());
    super.dispose();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'package:productivity/dataservice/assistant_service.dart';
import 'package:productivity/dataservice/sprachbefehle.dart';
import 'package:productivity/dataservice/transcription_service.dart';
import 'package:productivity/dataservice/tts_service.dart';
import 'package:productivity/dataservice/wakeword_service.dart';
import 'package:productivity/dataservice/wakeword_ton.dart';
import 'package:productivity/provider/tablet_seiten_provider.dart';

enum SprachZustand { ruht, hoert, denkt, spricht }

/// Der Sprach-Ablauf des Küchentablets: aufnehmen, verstehen, ausführen,
/// antworten.
///
/// Zwei Wege hinein, danach derselbe Ablauf: der Knopf auf dem Dashboard und
/// das Weckwort „Jarvis". Beide rufen [starten].
///
/// Der heikle Teil ist die Mikrofon-Übergabe. Porcupine hält den Audiostrom,
/// solange es lauscht; der Rekorder braucht ihn exklusiv. Deshalb genau eine
/// Reihenfolge, und sie steht in [starten] und [_zurueckInRuhe]:
///
///     Weckwort -> Porcupine anhalten -> aufnehmen -> verstehen -> ausführen
///     -> sprechen -> Porcupine fortsetzen
///
/// Das Fortsetzen liegt bewusst am gemeinsamen Rückweg und nicht am Ende des
/// Erfolgsfalls: sonst wäre Jarvis nach dem ersten Fehler dauerhaft taub.
class SprachProvider extends ChangeNotifier {
  SprachProvider(this._seiten);

  final TabletSeitenProvider _seiten;

  // ── Schwellen der Stille-Erkennung ────────────────────────────────────
  // Die Werte sind in dBFS (0 = Vollausschlag, Stille weit im Negativen) und
  // hängen am Mikrofon des Geräts. Auf dem Tab A8 mit seinem einzelnen
  // Mikrofon dürfen sie eher empfindlich sein; in einer lauten Küche muss
  // _schwelleStimme womöglich höher.
  static const double _schwelleStimme = -32.0;
  static const Duration _stillePause = Duration(milliseconds: 1200);
  static const Duration _maxVorlauf = Duration(seconds: 5);
  static const Duration _maxGesamt = Duration(seconds: 15);

  /// Am Anfang der Aufnahme werden Pegel ignoriert.
  ///
  /// Sonst zählt das Bestätigungs-Pling als Sprache: die Stille-Uhr liefe ab
  /// dem Ton, und wer nach „Hey Jarvis" eine Sekunde überlegt, würde
  /// abgeschnitten, bevor er den Satz beginnt. Dasselbe gilt für das
  /// Nachklingen des Weckworts selbst.
  static const Duration _blindzeit = Duration(milliseconds: 350);

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
  bool _beendet = false;

  /// Gesetzt, sobald der Nutzer abbricht. Die schon laufende Verarbeitung
  /// lässt sich nicht zurückrufen — aber sie darf danach nicht mehr reden.
  bool _abgebrochen = false;

  bool _wakewordAn = false;
  bool _wakewordLaeuft = false;
  String? _wakewordFehler;

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

    _verstanden = '';
    _antwort = '';
    _fehler = null;
    _offen.clear();
    _hatGesprochen = false;
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
    if (jetzt.difference(_begonnen!) < _blindzeit) return;

    if (amp.current > _schwelleStimme) {
      _hatGesprochen = true;
      _letzteStimme = jetzt;
    }

    if (!_hatGesprochen) {
      // Es hat nie jemand angefangen zu reden -> nicht endlos mitlaufen.
      if (jetzt.difference(_begonnen!) > _maxVorlauf) {
        _beenden(nichtsGehoert: true);
      }
      return;
    }

    if (jetzt.difference(_letzteStimme!) > _stillePause ||
        jetzt.difference(_begonnen!) > _maxGesamt) {
      _beenden();
    }
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
    await _antworte(teile.join(' '));
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

  Future<void> _antworte(String text) async {
    if (_abgebrochen) return;
    _antwort = text.trim();
    _setze(SprachZustand.spricht);
    await TtsService.sprich(_antwort);
    // Nach dem Abbruch ist der Zustand schon zurückgesetzt; ihn hier noch
    // einmal zu setzen würde die Anzeige aus einem Ablauf überschreiben, den
    // niemand mehr sehen will.
    if (!_abgebrochen) _zurueckInRuhe();
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

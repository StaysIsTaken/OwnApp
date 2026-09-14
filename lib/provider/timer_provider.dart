import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:productivity/dataservice/timer_ton.dart';

/// Der Zustand der Eieruhr — Dauer, Restzeit, läuft oder nicht.
///
/// Lag vorher als privater State in `TileClockView`. Herausgezogen aus
/// demselben Grund wie die Seiten in [TabletSeitenProvider]: die
/// Sprachbedienung muss von außen stellen können („Jarvis, stell einen Timer
/// für fünf Minuten"), und an privaten Widget-State kommt sie nicht heran.
///
/// Der Takt läuft nur, solange der Timer läuft. Eine Uhr, die im Leerlauf
/// jede Sekunde alles neu zeichnen lässt, kostet auf einem Wandtablet
/// dauerhaft Strom für nichts.
///
/// Gezählt wird pro Takt heruntergezählt, nicht gegen einen Zielzeitpunkt
/// gerechnet. Das ist bewusst: so bleibt der Timer das, was er laut Kachel
/// sein soll — eine Eieruhr für ein Gerät, das in der Küche eingeschaltet
/// steht. Wird die App vom Betriebssystem schlafen gelegt, steht auch der
/// Timer; er läuft dann nach, statt im Hintergrund abzulaufen.
class TimerProvider extends ChangeNotifier {
  /// Dieselbe Vorgabe wie bisher in der Kachel.
  static const Duration standard = Duration(minutes: 5);

  Timer? _takt;

  Duration _gestellt = standard;
  Duration _rest = standard;
  bool _laeuft = false;
  bool _hatGelaufen = false;

  /// Die eingestellte Dauer — das, worauf „Zurück" zurückstellt.
  Duration get gestellt => _gestellt;

  /// Was noch übrig ist.
  Duration get rest => _rest;

  bool get laeuft => _laeuft;

  /// Abgelaufen und noch nicht wieder angefasst.
  bool get abgelaufen => _rest <= Duration.zero && !_laeuft && _hatGelaufen;

  /// Stellt die Dauer, ohne zu starten.
  void stellen(Duration dauer) {
    if (dauer <= Duration.zero) return;
    TimerTon.aufhoeren();
    _gestellt = dauer;
    _rest = dauer;
    _hatGelaufen = false;
    notifyListeners();
  }

  /// Stellt und startet in einem — der Weg über die Sprache.
  ///
  /// Wer „stell einen Timer für fünf Minuten" sagt, will nicht danach noch
  /// zur Kachel laufen und auf Start tippen.
  void stelleUndStarte(Duration dauer) {
    if (dauer <= Duration.zero) return;
    stellen(dauer);
    starten();
  }

  void starten() {
    if (_laeuft) return;
    TimerTon.aufhoeren();
    if (_rest <= Duration.zero) _rest = _gestellt;
    if (_rest <= Duration.zero) return;
    _hatGelaufen = false;
    _laeuft = true;
    _taktAn();
    notifyListeners();
  }

  void pausieren() {
    if (!_laeuft) return;
    _laeuft = false;
    _taktAus();
    notifyListeners();
  }

  void startStopp() => _laeuft ? pausieren() : starten();

  void zuruecksetzen() {
    TimerTon.aufhoeren();
    _laeuft = false;
    _taktAus();
    _rest = _gestellt;
    _hatGelaufen = false;
    notifyListeners();
  }

  void _taktAn() {
    _takt ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _taktAus() {
    _takt?.cancel();
    _takt = null;
  }

  void _tick() {
    if (!_laeuft) return;
    final neu = _rest - const Duration(seconds: 1);
    if (neu <= Duration.zero) {
      _rest = Duration.zero;
      _laeuft = false;
      _hatGelaufen = true;
      _taktAus();
      // Genau einmal, beim Übergang auf null — selbst asynchron, der Ton
      // hält die Anzeige nicht auf.
      TimerTon.spielen();
    } else {
      _rest = neu;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _taktAus();
    // Sonst klingelt es weiter, während man längst etwas anderes ansieht.
    TimerTon.aufhoeren();
    super.dispose();
  }
}

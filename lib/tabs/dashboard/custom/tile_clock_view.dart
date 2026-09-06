import 'dart:async';

import 'package:flutter/material.dart';
import 'package:productivity/dataservice/timer_ton.dart';

/// Was die Uhr gerade tut.
enum Uhrfunktion { uhr, timer }

/// Uhrzeit als Text. Eigene Funktion, damit sie sich prüfen lässt, ohne
/// die Uhr zu zeichnen und auf eine Sekunde zu warten.
String zeitText(DateTime t, {bool mitSekunden = true}) {
  String zwei(int n) => n.toString().padLeft(2, '0');
  final hm = '${zwei(t.hour)}:${zwei(t.minute)}';
  return mitSekunden ? '$hm:${zwei(t.second)}' : hm;
}

const _wochentage = [
  'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag',
  'Freitag', 'Samstag', 'Sonntag',
];

String datumText(DateTime t) =>
    '${_wochentage[t.weekday - 1]}, ${t.day}.${t.month}.${t.year}';

/// Restzeit als Text.
///
/// Ab einer Stunde mit Stunden, darunter nur Minuten und Sekunden — auf
/// einem Eierkocher-Timer ist `00:04:30` schwerer zu lesen als `04:30`.
String dauerText(Duration d) {
  final rest = d.isNegative ? Duration.zero : d;
  String zwei(int n) => n.toString().padLeft(2, '0');
  final stunden = rest.inHours;
  final minuten = rest.inMinutes.remainder(60);
  final sekunden = rest.inSeconds.remainder(60);
  if (stunden > 0) return '$stunden:${zwei(minuten)}:${zwei(sekunden)}';
  return '${zwei(minuten)}:${zwei(sekunden)}';
}

/// Uhr und Timer in einer Kachel.
///
/// Sie braucht keine Einstellung: eine Uhr weiß, wie spät es ist. Was sie
/// zeigt, wählt man an ihr selbst — oben zwei Knöpfe, kein Umweg über den
/// Kacheleditor. Für ein Gerät in der Küche ist das der Unterschied
/// zwischen „schnell einen Timer stellen" und „erst mal einrichten".
///
/// Der Timer läuft im Widget, nicht auf dem Server. Er überlebt deshalb
/// keinen Neustart der App — was für eine Eieruhr genau richtig ist und
/// für alles andere zu wenig wäre.
class TileClockView extends StatefulWidget {
  /// Grosse Ziffern – fuer ein Geraet an der Wand.
  final bool gross;

  const TileClockView({super.key, this.gross = false});

  @override
  State<TileClockView> createState() => _TileClockViewState();
}

class _TileClockViewState extends State<TileClockView> {
  Timer? _takt;
  DateTime _jetzt = DateTime.now();

  Uhrfunktion _funktion = Uhrfunktion.uhr;

  /// Eingestellte Dauer und was davon noch übrig ist.
  Duration _gestellt = const Duration(minutes: 5);
  Duration _rest = const Duration(minutes: 5);
  bool _laeuft = false;

  bool get _abgelaufen => _rest <= Duration.zero && !_laeuft && _hatGelaufen;
  bool _hatGelaufen = false;

  @override
  void initState() {
    super.initState();
    // Ein Takt für beides: die Uhr braucht ihn ohnehin, und zwei Timer
    // nebeneinander laufen unweigerlich auseinander.
    _takt = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _jetzt = DateTime.now();
      if (_laeuft) {
        final neu = _rest - const Duration(seconds: 1);
        if (neu <= Duration.zero) {
          _rest = Duration.zero;
          _laeuft = false;
          _hatGelaufen = true;
          // Genau einmal, beim Übergang auf null. Im setState aufgerufen,
          // aber selbst asynchron – der Ton hält die Anzeige nicht auf.
          TimerTon.spielen();
        } else {
          _rest = neu;
        }
      }
    });
  }

  @override
  void dispose() {
    _takt?.cancel();
    // Sonst klingelt es weiter, während man längst etwas anderes ansieht.
    TimerTon.aufhoeren();
    super.dispose();
  }

  void _stellen(Duration d) {
    TimerTon.aufhoeren();
    setState(() {
      _gestellt = d;
      _rest = d;
      _hatGelaufen = false;
    });
  }

  void _startStopp() {
    // Wer wieder startet, hat das Klingeln zur Kenntnis genommen.
    TimerTon.aufhoeren();
    setState(() {
      if (_rest <= Duration.zero) _rest = _gestellt;
      _hatGelaufen = false;
      _laeuft = !_laeuft;
    });
  }

  void _zuruecksetzen() {
    TimerTon.aufhoeren();
    setState(() {
      _laeuft = false;
      _rest = _gestellt;
      _hatGelaufen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Die Funktionswahl sitzt an der Uhr, nicht im Editor.
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<Uhrfunktion>(
            segments: const [
              ButtonSegment(
                value: Uhrfunktion.uhr,
                icon: Icon(Icons.schedule_rounded),
                label: Text('Uhr'),
              ),
              ButtonSegment(
                value: Uhrfunktion.timer,
                icon: Icon(Icons.timer_outlined),
                label: Text('Timer'),
              ),
            ],
            selected: {_funktion},
            showSelectedIcon: false,
            onSelectionChanged: (w) => setState(() => _funktion = w.first),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _funktion == Uhrfunktion.uhr
              ? _uhr(colors)
              : _timer(colors),
        ),
      ],
    );
  }

  Widget _uhr(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            child: Text(
              zeitText(_jetzt),
              style: TextStyle(
                fontSize: widget.gross ? 92 : 44,
                fontWeight: FontWeight.w300,
                // Feste Ziffernbreite: sonst zappelt die Uhr bei jedem
                // Sekundenwechsel hin und her.
                fontFeatures: const [FontFeature.tabularFigures()],
                color: colors.onSurface,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            datumText(_jetzt),
            style: TextStyle(
              fontSize: widget.gross ? 20 : 13,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timer(ColorScheme colors) {
    final fertig = _abgelaufen;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          child: Text(
            dauerText(_rest),
            style: TextStyle(
              fontSize: widget.gross ? 84 : 40,
              fontWeight: FontWeight.w300,
              fontFeatures: const [FontFeature.tabularFigures()],
              // Abgelaufen faellt ins Auge – ohne Ton bleibt nur die Farbe.
              color: fertig ? colors.error : colors.onSurface,
              height: 1.0,
            ),
          ),
        ),
        if (fertig)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Fertig!',
                style: TextStyle(
                    fontSize: widget.gross ? 24 : 15,
                    fontWeight: FontWeight.bold,
                    color: colors.error)),
          ),
        const SizedBox(height: 12),
        // Vorgaben statt eines Zahlenfelds: in der Kueche stellt man drei,
        // fuenf oder zehn Minuten, nicht 7:23.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final minuten in const [1, 3, 5, 10, 15, 30])
              ChoiceChip(
                label: Text('$minuten min'),
                selected: !_laeuft && _gestellt.inMinutes == minuten,
                onSelected: (_) => _stellen(Duration(minutes: minuten)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _startStopp,
              icon: Icon(_laeuft
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded),
              label: Text(_laeuft ? 'Pause' : 'Start'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _zuruecksetzen,
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Zurück'),
            ),
          ],
        ),
      ],
    );
  }
}

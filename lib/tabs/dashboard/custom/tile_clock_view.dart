import 'dart:async';

import 'package:flutter/material.dart';
import 'package:productivity/provider/timer_provider.dart';
import 'package:provider/provider.dart';

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

  /// Der Timer selbst liegt im [TimerProvider] — er muss weiterlaufen,
  /// während diese Kachel gar nicht zu sehen ist, und per Sprache stellbar
  /// sein.
  TimerProvider? _steuerung;
  bool _liefZuletzt = false;

  /// Die Vorgaben bleiben — sie decken den haeufigen Fall in einem Tipp ab.
  static const _vorgaben = [1, 3, 5, 10, 15, 30];

  /// Entspricht die eingestellte Dauer genau einer Vorgabe?
  ///
  /// Davon haengt nur ab, welcher Knopf hervorgehoben ist — aber ohne das
  /// saehe „7:23 eingestellt" aus wie „nichts eingestellt".
  bool _istVorgabe(Duration gestellt) =>
      gestellt.inSeconds % 60 == 0 && _vorgaben.contains(gestellt.inMinutes);

  @override
  void initState() {
    super.initState();
    // Eigener Takt nur noch fuer die Uhrzeit. Die Restzeit zaehlt der
    // Provider — frueher lief beides an einem Takt, aber der sass im Widget
    // und stand damit still, sobald man die Kachel verliess.
    _takt = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _jetzt = DateTime.now());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final gefunden = context.read<TimerProvider>();
    if (identical(gefunden, _steuerung)) return;
    _steuerung?.removeListener(_timerWechsel);
    _steuerung = gefunden..addListener(_timerWechsel);
    _liefZuletzt = gefunden.laeuft;
  }

  /// Faengt der Timer von aussen an zu laufen — per Sprache —, zeigt die
  /// Kachel ihn auch. Wer zuruft, will das Herunterzaehlen sehen und nicht
  /// die Uhrzeit, vor der er ohnehin steht.
  void _timerWechsel() {
    final laeuft = _steuerung?.laeuft ?? false;
    if (laeuft && !_liefZuletzt && _funktion != Uhrfunktion.timer && mounted) {
      setState(() => _funktion = Uhrfunktion.timer);
    }
    _liefZuletzt = laeuft;
  }

  Future<void> _eigeneZeit(TimerProvider steuerung) async {
    final gewaehlt = await showDialog<Duration>(
      context: context,
      builder: (_) => _EigeneZeit(vorgabe: steuerung.gestellt),
    );
    if (gewaehlt != null && gewaehlt > Duration.zero) steuerung.stellen(gewaehlt);
  }

  @override
  void dispose() {
    _takt?.cancel();
    // Der Ton wird hier NICHT mehr gestoppt: der Timer gehoert jetzt der
    // App, nicht dieser Kachel. Wer weiterblaettert, waehrend er klingelt,
    // soll ihn trotzdem hoeren.
    _steuerung?.removeListener(_timerWechsel);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final steuerung = context.watch<TimerProvider>();

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
              : _timer(colors, steuerung),
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

  Widget _timer(ColorScheme colors, TimerProvider steuerung) {
    final fertig = steuerung.abgelaufen;
    final gestellt = steuerung.gestellt;
    final istVorgabe = _istVorgabe(gestellt);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          child: Text(
            dauerText(steuerung.rest),
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
        // Vorgaben fuer den haeufigen Fall: in der Kueche stellt man drei,
        // fuenf oder zehn Minuten. Wer 7:23 braucht, tippt auf „Eigene".
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final minuten in _vorgaben)
              ChoiceChip(
                label: Text('$minuten min'),
                selected: !steuerung.laeuft &&
                    istVorgabe &&
                    gestellt.inMinutes == minuten,
                onSelected: (_) => steuerung.stellen(Duration(minutes: minuten)),
              ),
            ChoiceChip(
              avatar: const Icon(Icons.tune_rounded, size: 18),
              label: Text(istVorgabe ? 'Eigene' : dauerText(gestellt)),
              selected: !steuerung.laeuft && !istVorgabe,
              onSelected: (_) => _eigeneZeit(steuerung),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: steuerung.startStopp,
              icon: Icon(steuerung.laeuft
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded),
              label: Text(steuerung.laeuft ? 'Pause' : 'Start'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: steuerung.zuruecksetzen,
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Zurück'),
            ),
          ],
        ),
      ],
    );
  }
}


/// Minuten und Sekunden von Hand stellen.
///
/// Zwei Reihen mit grossen Plus- und Minusknoepfen statt eines Tastenfelds:
/// das hier wird mit dem Daumen bedient, oft mit mehligen Fingern. Die
/// Minuten springen in Fuenferschritten, wenn man den grossen Knopf nimmt —
/// von 5 auf 45 in acht Tipps statt in vierzig.
class _EigeneZeit extends StatefulWidget {
  final Duration vorgabe;

  const _EigeneZeit({required this.vorgabe});

  @override
  State<_EigeneZeit> createState() => _EigeneZeitState();
}

class _EigeneZeitState extends State<_EigeneZeit> {
  late int _minuten = widget.vorgabe.inMinutes.clamp(0, 599);
  late int _sekunden = widget.vorgabe.inSeconds.remainder(60);

  Duration get _dauer => Duration(minutes: _minuten, seconds: _sekunden);

  void _aendern({int minuten = 0, int sekunden = 0}) {
    setState(() {
      // Ueber die Sekundengrenze hinaus wird umgerechnet statt gedeckelt:
      // wer bei 55 Sekunden zweimal auf +10 tippt, meint 1:15 und nicht
      // "geht nicht".
      final gesamt = (_minuten * 60 + _sekunden + minuten * 60 + sekunden)
          .clamp(0, 599 * 60 + 59);
      _minuten = gesamt ~/ 60;
      _sekunden = gesamt % 60;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Eigene Zeit'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dauerText(_dauer),
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w300,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 20),
            _Reihe(
              titel: 'Minuten',
              wert: _minuten,
              onWeniger: () => _aendern(minuten: -1),
              onMehr: () => _aendern(minuten: 1),
              onVielWeniger: () => _aendern(minuten: -5),
              onVielMehr: () => _aendern(minuten: 5),
            ),
            const SizedBox(height: 12),
            _Reihe(
              titel: 'Sekunden',
              wert: _sekunden,
              onWeniger: () => _aendern(sekunden: -1),
              onMehr: () => _aendern(sekunden: 1),
              onVielWeniger: () => _aendern(sekunden: -10),
              onVielMehr: () => _aendern(sekunden: 10),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen')),
        FilledButton(
          // Null Sekunden sind keine Zeit, die man stellen will.
          onPressed: _dauer > Duration.zero
              ? () => Navigator.pop(context, _dauer)
              : null,
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}

class _Reihe extends StatelessWidget {
  final String titel;
  final int wert;
  final VoidCallback onWeniger;
  final VoidCallback onMehr;
  final VoidCallback onVielWeniger;
  final VoidCallback onVielMehr;

  const _Reihe({
    required this.titel,
    required this.wert,
    required this.onWeniger,
    required this.onMehr,
    required this.onVielWeniger,
    required this.onVielMehr,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        SizedBox(width: 90, child: Text(titel, style: text.bodyLarge)),
        IconButton.filledTonal(
          onPressed: onVielWeniger,
          icon: const Icon(Icons.keyboard_double_arrow_left_rounded),
          tooltip: 'Deutlich weniger',
        ),
        IconButton(
            onPressed: onWeniger, icon: const Icon(Icons.remove_rounded)),
        SizedBox(
          width: 52,
          child: Text(
            wert.toString().padLeft(2, '0'),
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        IconButton(onPressed: onMehr, icon: const Icon(Icons.add_rounded)),
        IconButton.filledTonal(
          onPressed: onVielMehr,
          icon: const Icon(Icons.keyboard_double_arrow_right_rounded),
          tooltip: 'Deutlich mehr',
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/kalender.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/dataservice/calendar_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/tabs/dashboard/seiten_einstellungen.dart';

/// Zeigt über der Wochenansicht, welche Kalender darin stehen — und lässt
/// sie an Ort und Stelle an- und abwählen.
///
/// Vorher lag dieselbe Einstellung in einem Dialog hinter einem Knopf. Das
/// war zweimal falsch: man sah nicht, was gerade gezeigt wird, und man
/// musste raten, dass der Knopf überhaupt etwas mit dem Raster darunter zu
/// tun hat. Eine Legende, die zugleich der Schalter ist, beantwortet beides
/// ohne ein Wort Erklärung.
///
/// Gedacht für ein Gerät in der Küche: große Flächen, ein Tipp genügt,
/// nichts versteckt sich hinter langem Drücken.
class KalenderLeiste extends StatefulWidget {
  final SeitenEinstellungen einstellungen;

  /// Wird bei jeder Änderung gerufen — die Seite speichert und lädt neu.
  final ValueChanged<SeitenEinstellungen> onGeaendert;

  /// Holt die Seite gerade die Termine zur neuen Auswahl?
  ///
  /// Ohne dieses Zeichen sieht ein Tipp aus, als sei nichts passiert: die
  /// Termine darunter brauchen ihren Weg zum Server, und bis sie da sind,
  /// steht die alte Woche im Raster. Ein Strich unter der Leiste sagt,
  /// dass gearbeitet wird — und nimmt ihr nicht den Platz weg.
  final bool laedt;

  const KalenderLeiste({
    super.key,
    required this.einstellungen,
    required this.onGeaendert,
    this.laedt = false,
  });

  @override
  State<KalenderLeiste> createState() => _KalenderLeisteState();
}

class _KalenderLeisteState extends State<KalenderLeiste> {
  List<Kalender> _kalender = [];
  bool _laedt = true;
  String? _fehler;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  @override
  void didUpdateWidget(KalenderLeiste alt) {
    super.didUpdateWidget(alt);
    // Der Schalter „auch die der anderen" ändert, welche Kalender es
    // überhaupt zu sehen gibt.
    if (alt.einstellungen.alleKalender != widget.einstellungen.alleKalender) {
      _laden();
    }
  }

  Future<void> _laden() async {
    setState(() {
      _laedt = true;
      _fehler = null;
    });
    try {
      final liste =
          await CalendarService.laden(alle: widget.einstellungen.alleKalender);
      if (!mounted) return;
      setState(() {
        _kalender = liste;
        _laedt = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _laedt = false;
        _fehler = ApiFehler.istVerboten(e)
            ? 'Keine Berechtigung für Kalender'
            : 'Kalender nicht erreichbar';
      });
    }
  }

  bool _istAn(Kalender k) =>
      widget.einstellungen.kalender == null ||
      widget.einstellungen.kalender!.contains(k.id);

  void _umschalten(Kalender k) {
    // Aus „alle" wird beim ersten Abwählen eine echte Liste – vorher gibt
    // es keine, weil „alle" auch neu hinzukommende einschließt.
    final liste = widget.einstellungen.kalender == null
        ? _kalender.map((e) => e.id).toList()
        : List<int>.from(widget.einstellungen.kalender!);

    if (_istAn(k)) {
      liste.remove(k.id);
    } else if (!liste.contains(k.id)) {
      liste.add(k.id);
    }
    widget.onGeaendert(
      SeitenEinstellungen(
        kalender: liste,
        alleKalender: widget.einstellungen.alleKalender,
      ),
    );
  }

  Future<void> _verwalten() async {
    await Navigator.pushNamed(context, AppRoutes.kalender);
    if (mounted) _laden();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _leiste(colors),
          // Immer da, nur meist unsichtbar: ein Strich, der beim Laden
          // erscheint und die Leiste sonst nicht verrueckt.
          SizedBox(
            height: 3,
            child: widget.laedt
                ? const LinearProgressIndicator(minHeight: 3)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _leiste(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(Icons.calendar_month_outlined,
              size: 22, color: colors.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: _laedt
                ? const SizedBox(
                    height: 40,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : _fehler != null
                    ? Text(_fehler!, style: TextStyle(color: colors.error))
                    : _chips(),
          ),
          const SizedBox(width: 8),
          // Anlegen liegt bewusst hier daneben: wer merkt, dass die
          // Müllabfuhr fehlt, will sie sofort anlegen können.
          IconButton.filledTonal(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Kalender anlegen oder verwalten',
            iconSize: 24,
            onPressed: _verwalten,
          ),
        ],
      ),
    );
  }

  /// Was auf dem Chip steht.
  ///
  /// Normalerweise der Name. Aber **der eigene Kalender heisst bei jedem
  /// „Mein Kalender"**, und im Haushalt stehen dann drei gleich
  /// beschriftete Chips nebeneinander — man kann nicht wissen, wen man
  /// gerade abwaehlt. Kommt ein Name mehrfach vor, tritt der Besitzer
  /// dazu; beim gemeinsamen Kalender ist das der Haushalt.
  ///
  /// Nur bei Doppelung, nicht immer: „Muellabfuhr (Jan)" ist laenger und
  /// sagt nichts dazu, und auf einem Tablet ist die Leiste schmal.
  String _beschriftung(Kalender k) {
    final mehrfach =
        _kalender.where((a) => a.name == k.name).length > 1;
    if (!mehrfach || k.ownerName.isEmpty) return k.name;
    return '${k.name} · ${k.ownerName}';
  }

  Widget _chips() {
    if (_kalender.isEmpty) {
      return Text(
        'Noch kein Kalender — rechts auf + tippen.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final k in _kalender)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FilterChip(
                selected: _istAn(k),
                onSelected: (_) => _umschalten(k),
                showCheckmark: false,
                // Der Punkt trägt die Farbe des Kalenders – dieselbe, in der
                // seine Termine im Raster darunter stehen.
                avatar: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _farbe(k.color),
                    shape: BoxShape.circle,
                  ),
                ),
                label: Text(_beschriftung(k),
                    style: const TextStyle(fontSize: 15)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
            ),
        ],
      ),
    );
  }
}

Color _farbe(String hex) {
  final roh = hex.replaceFirst('#', '');
  final wert = int.tryParse(roh, radix: 16);
  return wert == null ? const Color(0xFF3B82F6) : Color(0xFF000000 | wert);
}

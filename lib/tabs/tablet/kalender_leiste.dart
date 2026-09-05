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

  const KalenderLeiste({
    super.key,
    required this.einstellungen,
    required this.onGeaendert,
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
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
                label: Text(k.name, style: const TextStyle(fontSize: 15)),
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

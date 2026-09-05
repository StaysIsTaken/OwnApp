import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/kalender.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/dataservice/calendar_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/provider/permission_provider.dart';
import 'package:productivity/tabs/dashboard/seiten_einstellungen.dart';
import 'package:provider/provider.dart';

/// Welche Kalender diese Seite zeigt.
///
/// Das ist die Stelle, an der sich „Müllabfuhr nur auf dieser Seite"
/// erfüllt: der Kalender existiert für alle, aber jede Seite entscheidet
/// für sich, ob sie ihn einblendet.
///
/// Bewusst großzügig gebaut — Zeilen zum Antippen statt einer Reihe
/// gedrängter Kästchen, und zu jedem Schalter ein Satz, was er tut. Das
/// hier wird auf einem Gerät bedient, das in der Küche steht.
Future<SeitenEinstellungen?> zeigeKalenderAuswahl(
  BuildContext context, {
  required SeitenEinstellungen aktuell,
}) {
  return showDialog<SeitenEinstellungen>(
    context: context,
    builder: (_) => _KalenderAuswahl(aktuell: aktuell),
  );
}

class _KalenderAuswahl extends StatefulWidget {
  final SeitenEinstellungen aktuell;
  const _KalenderAuswahl({required this.aktuell});

  @override
  State<_KalenderAuswahl> createState() => _KalenderAuswahlState();
}

class _KalenderAuswahlState extends State<_KalenderAuswahl> {
  List<Kalender> _kalender = [];
  late bool _alle = widget.aktuell.alleKalender;

  /// Null heißt „alle sichtbaren". Erst wenn jemand etwas abwählt, wird
  /// daraus eine echte Liste.
  late List<int>? _gewaehlt = widget.aktuell.kalender;

  bool _laedt = true;
  String? _fehler;

  /// „Dir fehlt ein Recht" ist etwas anderes als „der Server antwortet
  /// nicht" — und nur beim Ersten hilft ein Administrator weiter. Vorher
  /// stand hier für beides derselbe nichtssagende Satz.
  bool _verboten = false;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    setState(() {
      _laedt = true;
      _fehler = null;
      _verboten = false;
    });
    try {
      final liste = await CalendarService.laden(alle: _alle);
      if (!mounted) return;
      setState(() {
        _kalender = liste;
        _laedt = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _laedt = false;
        _verboten = ApiFehler.istVerboten(e);
        _fehler = _verboten
            ? 'Für Kalender fehlt dieser Rolle das Recht „planner:read".\n'
                'Ein Administrator kann es vergeben.'
            : 'Die Kalender konnten nicht geladen werden.';
      });
    }
  }

  bool _istAn(Kalender k) => _gewaehlt == null || _gewaehlt!.contains(k.id);

  void _umschalten(Kalender k, bool an) {
    setState(() {
      // Aus „alle" wird beim ersten Abwählen eine echte Liste – vorher gibt
      // es keine, weil „alle" auch neu hinzukommende Kalender einschließt.
      final liste = _gewaehlt == null
          ? _kalender.map((e) => e.id).toList()
          : List<int>.from(_gewaehlt!);
      if (an) {
        if (!liste.contains(k.id)) liste.add(k.id);
      } else {
        liste.remove(k.id);
      }
      _gewaehlt = liste;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final darfAlle = context.read<PermissionProvider>().darf('planner:read_all');

    return AlertDialog(
      title: const Text('Welche Kalender zeigt diese Seite?'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (darfAlle) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _alle,
                title: const Text('Auch die Kalender der anderen'),
                subtitle: const Text(
                  'Privat markierte Termine bleiben verborgen — auch hier.',
                ),
                onChanged: (v) {
                  setState(() {
                    _alle = v;
                    // Die Auswahl passt nicht mehr: beim Ausschalten stünden
                    // sonst fremde Kalender-IDs in der Liste, die es hier
                    // gar nicht mehr gibt.
                    _gewaehlt = null;
                  });
                  _laden();
                },
              ),
              const Divider(height: 24),
            ],
            Text(
              _gewaehlt == null
                  ? 'Zurzeit sind alle eingeblendet. Neue Kalender kommen '
                      'automatisch dazu.'
                  : 'Nur die angehakten werden gezeigt.',
              style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: _laedt
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _fehler != null
                      ? _Fehlerzeile(text: _fehler!, onNochmal: _laden)
                      : _liste(),
            ),
          ],
        ),
      ),
      actions: [
        // Von hier aus erreichbar: sonst sucht man die Verwaltung im Menü,
        // während man gerade vor der leeren Auswahl steht.
        TextButton.icon(
          icon: const Icon(Icons.settings_outlined, size: 18),
          label: const Text('Kalender verwalten'),
          onPressed: () async {
            await Navigator.pushNamed(context, AppRoutes.kalender);
            if (context.mounted) _laden();
          },
        ),
        // Zurück auf „alle" – der Weg heraus, wenn man sich verklickt hat.
        if (_gewaehlt != null)
          TextButton(
            onPressed: () => setState(() => _gewaehlt = null),
            child: const Text('Alle einblenden'),
          ),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            SeitenEinstellungen(kalender: _gewaehlt, alleKalender: _alle),
          ),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }

  Widget _liste() {
    if (_kalender.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Es gibt noch keine Kalender. Über „Kalender verwalten" '
            'lässt sich einer anlegen — etwa für die Müllabfuhr.'),
      );
    }
    return ListView(
      shrinkWrap: true,
      children: [
        for (final k in _kalender)
          CheckboxListTile(
            value: _istAn(k),
            onChanged: (v) => _umschalten(k, v ?? false),
            secondary: _Punkt(farbe: k.color),
            title: Text(k.name, style: const TextStyle(fontSize: 16)),
            subtitle: Text(_beschreibung(k)),
            // Große Zeilen: das wird mit dem Daumen bedient.
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
          ),
      ],
    );
  }

  /// Sagt in einer Zeile, was für ein Kalender das ist — sonst stehen dort
  /// drei „Privat" untereinander und niemand weiß, welches wessen ist.
  String _beschreibung(Kalender k) {
    final teile = <String>[
      if (_alle) k.ownerName,
      if (k.istAbonniert) 'abonniert' else if (k.istStandard) 'Standard',
      '${k.anzahlTermine} ${k.anzahlTermine == 1 ? "Termin" : "Termine"}',
    ];
    return teile.where((t) => t.isNotEmpty).join(' · ');
  }
}

class _Punkt extends StatelessWidget {
  final String farbe;
  const _Punkt({required this.farbe});

  @override
  Widget build(BuildContext context) {
    var wert = 0xFF3B82F6;
    if (farbe.startsWith('#') && farbe.length == 7) {
      final geparst = int.tryParse(farbe.substring(1), radix: 16);
      if (geparst != null) wert = 0xFF000000 | geparst;
    }
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(color: Color(wert), shape: BoxShape.circle),
    );
  }
}

class _Fehlerzeile extends StatelessWidget {
  final String text;
  final VoidCallback onNochmal;
  const _Fehlerzeile({required this.text, required this.onNochmal});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: onNochmal, child: const Text('Nochmal')),
          ],
        ),
      );
}

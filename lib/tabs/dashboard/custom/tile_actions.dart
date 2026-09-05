import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/kalender.dart';
import 'package:productivity/dataclasses/planner_entry_type.dart';
import 'package:productivity/dataservice/calendar_service.dart';
import 'package:productivity/dataclasses/task.dart';
import 'package:productivity/dataservice/planner_service.dart';
import 'package:productivity/dataservice/task_service.dart';
import 'package:productivity/tabs/dashboard/custom/tile_spec.dart';

/// Die kleinen Handlungen, die Kacheln an Ort und Stelle anbieten.
///
/// Bewusst knapp gehalten: ein Titel, ein Zeitpunkt, fertig. Wer mehr
/// einstellen will — Beschreibung, Teilnehmer, Wiederholung —, ist auf der
/// großen Seite besser aufgehoben, und dorthin führt die Kachel ohnehin
/// beim Antippen. Ein zweites vollständiges Formular an dieser Stelle wäre
/// eine zweite Stelle, die man pflegen muss.
class TileAktionen {
  TileAktionen._();

  /// „+ Termin" — auf der Wochenansicht und den Terminkacheln.
  static TileAktion termin({DateTime? vorschlag}) => TileAktion(
        label: 'Termin',
        icon: Icons.event_available_outlined,
        recht: 'planner:write',
        ausfuehren: (context) async =>
            await showDialog<bool>(
              context: context,
              builder: (_) => _TerminDialog(vorschlag: vorschlag),
            ) ??
            false,
      );

  /// „+ Aufgabe" — auf den Aufgabenkacheln.
  static TileAktion get aufgabe => TileAktion(
        label: 'Aufgabe',
        icon: Icons.add_task_rounded,
        recht: 'tasks:write',
        ausfuehren: (context) async =>
            await showDialog<bool>(
              context: context,
              builder: (_) => const _AufgabenDialog(),
            ) ??
            false,
      );
}

// ── Termin ──────────────────────────────────────────────────────────────

class _TerminDialog extends StatefulWidget {
  final DateTime? vorschlag;
  const _TerminDialog({this.vorschlag});

  @override
  State<_TerminDialog> createState() => _TerminDialogState();
}

class _TerminDialogState extends State<_TerminDialog> {
  final _titel = TextEditingController();
  late DateTime _tag;
  late TimeOfDay _uhrzeit;
  int _dauer = 60;

  List<PlannerEntryType> _typen = [];
  int? _typ;

  /// In welchen Kalender der Termin soll. Ohne Auswahl entscheidet das
  /// Backend (Standardkalender) — deshalb darf das null bleiben.
  List<Kalender> _kalender = [];
  int? _kalenderId;

  bool _laedt = true;
  bool _speichert = false;
  String? _fehler;

  @override
  void initState() {
    super.initState();
    // Auf die nächste volle Stunde: der häufigste Fall, und niemand will
    // 14:37 als Startzeit wegklicken.
    final start = widget.vorschlag ?? DateTime.now().add(const Duration(hours: 1));
    _tag = DateTime(start.year, start.month, start.day);
    _uhrzeit = TimeOfDay(hour: start.hour, minute: 0);
    _typenLaden();
  }

  Future<void> _typenLaden() async {
    try {
      // Beides zusammen: ein Dialog, der zweimal nacheinander laedt, steht
      // doppelt so lange leer da.
      final ergebnis = await Future.wait([
        PlannerService.loadTypes(),
        CalendarService.laden().catchError((_) => <Kalender>[]),
      ]);
      final typen = ergebnis[0] as List<PlannerEntryType>;
      final kalender = ergebnis[1] as List<Kalender>;
      if (!mounted) return;
      setState(() {
        _typen = typen;
        _typ = typen.isEmpty ? null : typen.first.id;
        _kalender = kalender;
        // Der Standardkalender ist die richtige Vorgabe – wer woanders hin
        // will, sagt es ausdruecklich.
        _kalenderId = kalender
            .where((k) => k.istStandard)
            .map((k) => k.id)
            .firstOrNull ??
            kalender.map((k) => k.id).firstOrNull;
        _laedt = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Ohne Typ lässt sich kein Termin anlegen – das gehört gesagt, nicht
      // erst beim Speichern als kryptische 422.
      setState(() {
        _laedt = false;
        _fehler = 'Die Terminarten konnten nicht geladen werden.';
      });
    }
  }

  @override
  void dispose() {
    _titel.dispose();
    super.dispose();
  }

  Future<void> _speichern() async {
    final titel = _titel.text.trim();
    if (titel.isEmpty || _typ == null) return;
    setState(() => _speichert = true);
    final start = DateTime(
        _tag.year, _tag.month, _tag.day, _uhrzeit.hour, _uhrzeit.minute);
    try {
      await PlannerService.create(
        title: titel,
        typeId: _typ!,
        scheduledAt: start,
        endsAt: start.add(Duration(minutes: _dauer)),
        calendarId: _kalenderId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _speichert = false;
        _fehler = 'Konnte nicht angelegt werden: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_laedt) {
      return const AlertDialog(
        content: SizedBox(
            height: 80, child: Center(child: CircularProgressIndicator())),
      );
    }

    return AlertDialog(
      title: const Text('Neuer Termin'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titel,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Worum geht es?',
                hintText: 'z. B. Zahnarzt',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _Waehler(
                    icon: Icons.event_outlined,
                    label: 'Tag',
                    wert: '${_tag.day}.${_tag.month}.${_tag.year}',
                    onDruck: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _tag,
                        firstDate: DateTime(_tag.year - 1),
                        lastDate: DateTime(_tag.year + 5),
                      );
                      if (d != null) setState(() => _tag = d);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Waehler(
                    icon: Icons.schedule_rounded,
                    label: 'Beginn',
                    wert: _uhrzeit.format(context),
                    onDruck: () async {
                      final t = await showTimePicker(
                          context: context, initialTime: _uhrzeit);
                      if (t != null) setState(() => _uhrzeit = t);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              initialValue: _dauer,
              decoration: const InputDecoration(labelText: 'Dauer'),
              items: const [
                DropdownMenuItem(value: 15, child: Text('15 Minuten')),
                DropdownMenuItem(value: 30, child: Text('30 Minuten')),
                DropdownMenuItem(value: 60, child: Text('1 Stunde')),
                DropdownMenuItem(value: 120, child: Text('2 Stunden')),
                DropdownMenuItem(value: 480, child: Text('Ganzer Tag')),
              ],
              onChanged: (v) => setState(() => _dauer = v ?? 60),
            ),
            if (_typen.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _typ,
                decoration: const InputDecoration(labelText: 'Art'),
                items: [
                  for (final t in _typen)
                    DropdownMenuItem(value: t.id, child: Text(t.name)),
                ],
                onChanged: (v) => setState(() => _typ = v),
              ),
            ],
            // Der Grund, warum es das hier gibt: ein Termin in der Kueche
            // gehoert oft nicht in den eigenen Kalender, sondern in den
            // gemeinsamen oder den fuer die Muellabfuhr.
            if (_kalender.length > 1) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _kalenderId,
                decoration: const InputDecoration(labelText: 'In welchen Kalender?'),
                items: [
                  for (final k in _kalender)
                    DropdownMenuItem(
                      value: k.id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12, height: 12,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: _farbe(k.color), shape: BoxShape.circle),
                          ),
                          Text(k.name),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _kalenderId = v),
              ),
            ],
            if (_fehler != null) ...[
              const SizedBox(height: 16),
              Text(_fehler!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _speichert ? null : () => Navigator.pop(context, false),
            child: const Text('Abbrechen')),
        FilledButton(
          onPressed:
              (_speichert || _titel.text.trim().isEmpty || _typ == null)
                  ? null
                  : _speichern,
          child: const Text('Eintragen'),
        ),
      ],
    );
  }
}

// ── Aufgabe ─────────────────────────────────────────────────────────────

class _AufgabenDialog extends StatefulWidget {
  const _AufgabenDialog();

  @override
  State<_AufgabenDialog> createState() => _AufgabenDialogState();
}

class _AufgabenDialogState extends State<_AufgabenDialog> {
  final _titel = TextEditingController();
  DateTime? _faellig;
  String _prio = 'medium';
  bool _speichert = false;
  String? _fehler;

  @override
  void dispose() {
    _titel.dispose();
    super.dispose();
  }

  Future<void> _speichern() async {
    final titel = _titel.text.trim();
    if (titel.isEmpty) return;
    setState(() => _speichert = true);
    try {
      // id, userId und die Zeitstempel vergibt der Server; hier stehen sie
      // nur, weil die Datenklasse sie verlangt.
      final jetzt = DateTime.now();
      await TaskService.create(Task(
        id: '',
        title: titel,
        dueDate: _faellig,
        priority: _prio,
        userId: '',
        createdAt: jetzt,
        updatedAt: jetzt,
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _speichert = false;
        _fehler = 'Konnte nicht angelegt werden: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neue Aufgabe'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titel,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Was ist zu tun?',
                hintText: 'z. B. Altpapier rausbringen',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            _Waehler(
              icon: Icons.event_outlined,
              label: 'Fällig',
              wert: _faellig == null
                  ? 'Ohne Datum'
                  : '${_faellig!.day}.${_faellig!.month}.${_faellig!.year}',
              onDruck: () async {
                final heute = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: _faellig ?? heute,
                  firstDate: DateTime(heute.year - 1),
                  lastDate: DateTime(heute.year + 5),
                );
                if (d != null) setState(() => _faellig = d);
              },
              // Ein gesetztes Datum muss man auch wieder loswerden.
              onLoeschen:
                  _faellig == null ? null : () => setState(() => _faellig = null),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _prio,
              decoration: const InputDecoration(labelText: 'Priorität'),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Niedrig')),
                DropdownMenuItem(value: 'medium', child: Text('Mittel')),
                DropdownMenuItem(value: 'high', child: Text('Hoch')),
              ],
              onChanged: (v) => setState(() => _prio = v ?? 'medium'),
            ),
            if (_fehler != null) ...[
              const SizedBox(height: 16),
              Text(_fehler!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _speichert ? null : () => Navigator.pop(context, false),
            child: const Text('Abbrechen')),
        FilledButton(
          onPressed: (_speichert || _titel.text.trim().isEmpty)
              ? null
              : _speichern,
          child: const Text('Anlegen'),
        ),
      ],
    );
  }
}

/// Ein antippbares Feld mit Beschriftung — für Datum und Uhrzeit.
///
/// Große Trefferfläche: das hier wird auch mit dem Daumen an einem Gerät
/// bedient, das an der Wand hängt.
class _Waehler extends StatelessWidget {
  final IconData icon;
  final String label;
  final String wert;
  final VoidCallback onDruck;
  final VoidCallback? onLoeschen;

  const _Waehler({
    required this.icon,
    required this.label,
    required this.wert,
    required this.onDruck,
    this.onLoeschen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onDruck,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          suffixIcon: onLoeschen == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  tooltip: 'Datum entfernen',
                  onPressed: onLoeschen,
                ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        child: Text(wert, style: text.bodyLarge?.copyWith(color: colors.onSurface)),
      ),
    );
  }
}


Color _farbe(String hex) {
  final roh = hex.replaceFirst('#', '');
  final wert = int.tryParse(roh, radix: 16);
  return wert == null ? const Color(0xFF3B82F6) : Color(0xFF000000 | wert);
}

import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/kalender.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/dataservice/calendar_service.dart';
import 'package:productivity/dataclasses/planner_entry_type.dart';
import 'package:productivity/dataservice/planner_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/widgets/color_picker_dialog.dart';

/// Kalender anlegen, ändern, abholen, löschen.
///
/// Bisher gab es Kalender nur im Backend und in der Auswahl „welche zeigt
/// diese Seite" — anlegen konnte man keinen. Damit war die Müllabfuhr als
/// eigener Kalender zwar vorgesehen, aber nicht erreichbar.
///
/// Zwei Arten von Kalendern stehen hier nebeneinander:
///
/// * **Selbst gepflegt** — da trägt man Termine von Hand ein.
/// * **Abonniert** — eine ICS-Adresse, die regelmäßig geholt wird.
///   Müllabfuhr, Feiertage, Schulferien. Die Adresse trägt der Nutzer ein;
///   eine fest eingebaute Liste wäre nach dem ersten Umzug falsch.
class KalenderVerwaltenPage extends BasePage {
  const KalenderVerwaltenPage({super.key})
      : super(title: 'Kalender verwalten');

  @override
  Widget buildBody(BuildContext context) => const _Inhalt();
}

class _Inhalt extends StatefulWidget {
  const _Inhalt();

  @override
  State<_Inhalt> createState() => _InhaltState();
}

class _InhaltState extends State<_Inhalt> {
  List<Kalender> _kalender = [];
  bool _laedt = true;
  bool _alle = false;
  String? _fehler;

  /// Getrennt vom allgemeinen Fehler: „dir fehlt ein Recht" ist etwas
  /// anderes als „der Server antwortet nicht", und der Unterschied
  /// entscheidet, was man dagegen tun kann.
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
            ? 'Für Kalender fehlt dir das Recht „planner:read".'
            : 'Die Kalender konnten nicht geladen werden.';
      });
    }
  }

  void _melde(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _bearbeiten({Kalender? vorhanden}) async {
    final ergebnis = await showDialog<bool>(
      context: context,
      builder: (_) => _KalenderDialog(vorhanden: vorhanden),
    );
    if (ergebnis == true) await _laden();
  }

  Future<void> _abholen(Kalender k) async {
    _melde('„${k.name}" wird geholt …');
    try {
      final antwort = await CalendarService.abholen(k.id);
      _melde('„${k.name}" geholt: ${antwort['imported'] ?? 0} Termine.');
      await _laden();
    } catch (e) {
      // Die Meldung des Servers weiterreichen – „hat nicht geklappt" hilft
      // beim Suchen des Tippfehlers in der Adresse nicht.
      _melde(ApiFehler.text(e));
    }
  }

  /// Eine .ics-Datei einmalig in diesen Kalender einlesen.
  ///
  /// Das ist der andere Fall neben dem Abonnement: eine Datei, die man
  /// einmal bekommt und nicht regelmäßig holen will. Vorher ging beides
  /// nicht in einen bestimmten Kalender — alles fiel in den Standard.
  Future<void> _importieren(Kalender k) async {
    final ergebnis = await showDialog<bool>(
      context: context,
      builder: (_) => _ImportDialog(kalender: k),
    );
    if (ergebnis == true) await _laden();
  }

  Future<void> _loeschen(Kalender k) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('„${k.name}" löschen?'),
        content: const Text(
          'Die Termine darin bleiben erhalten — sie verlieren nur ihre '
          'Zuordnung. Einen Kalender wegzuräumen ist etwas anderes, als '
          'Termine zu löschen.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Löschen')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CalendarService.loeschen(k.id);
      await _laden();
    } catch (e) {
      _melde(ApiFehler.text(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_laedt) return const Center(child: CircularProgressIndicator());
    if (_fehler != null) return _fehlerAnsicht();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _laden,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          children: [
            SwitchListTile(
              value: _alle,
              title: const Text('Auch die Kalender der anderen'),
              subtitle: const Text(
                'Verlangt das Recht „planner:read_all". Ändern darfst du '
                'weiterhin nur die eigenen.',
              ),
              onChanged: (v) {
                setState(() => _alle = v);
                _laden();
              },
            ),
            const Divider(),
            if (_kalender.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'Noch kein Kalender. Unten rechts einen anlegen —\n'
                  'zum Beispiel einen für die Müllabfuhr.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              for (final k in _kalender) _zeile(k),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _bearbeiten(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Kalender'),
      ),
    );
  }

  Widget _zeile(Kalender k) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: _farbe(k.color), radius: 14),
        title: Text(k.name),
        subtitle: Text(_untertitel(k), style: text.bodySmall),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (k.istAbonniert)
              IconButton(
                icon: const Icon(Icons.sync_rounded),
                tooltip: 'Jetzt holen',
                onPressed: () => _abholen(k),
              ),
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: 'Termine aus einer .ics-Datei einlesen',
              onPressed: () => _importieren(k),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Ändern',
              onPressed: () => _bearbeiten(vorhanden: k),
            ),
            // Der Standardkalender lässt sich nicht löschen – jeder braucht
            // einen, in dem Termine ohne eigene Angabe landen.
            if (!k.istStandard)
              IconButton(
                icon: Icon(Icons.delete_outline, color: colors.error),
                tooltip: 'Löschen',
                onPressed: () => _loeschen(k),
              ),
          ],
        ),
      ),
    );
  }

  String _untertitel(Kalender k) {
    final teile = <String>[
      if (_alle) k.ownerName,
      if (k.istAbonniert)
        'abonniert${k.zuletztGeholt == null ? "" : ", zuletzt "
            "${k.zuletztGeholt!.day}.${k.zuletztGeholt!.month}."}'
      else if (k.istStandard)
        'Standard',
      '${k.anzahlTermine} ${k.anzahlTermine == 1 ? "Termin" : "Termine"}',
    ];
    return teile.where((t) => t.isNotEmpty).join(' · ');
  }

  Widget _fehlerAnsicht() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_verboten ? Icons.lock_outline : Icons.cloud_off_outlined,
                size: 56, color: colors.outline),
            const SizedBox(height: 16),
            Text(_fehler!, textAlign: TextAlign.center),
            if (_verboten) ...[
              const SizedBox(height: 8),
              Text(
                'Ein Administrator kann es der Rolle geben.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _laden, child: const Text('Nochmal')),
          ],
        ),
      ),
    );
  }
}

Color _farbe(String hex) {
  final roh = hex.replaceFirst('#', '');
  final wert = int.tryParse(roh, radix: 16);
  return wert == null ? const Color(0xFF3B82F6) : Color(0xFF000000 | wert);
}

// ── Anlegen und Ändern ──────────────────────────────────────────────────

class _KalenderDialog extends StatefulWidget {
  final Kalender? vorhanden;
  const _KalenderDialog({this.vorhanden});

  @override
  State<_KalenderDialog> createState() => _KalenderDialogState();
}

class _KalenderDialogState extends State<_KalenderDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.vorhanden?.name ?? '');
  late final TextEditingController _ics =
      TextEditingController(text: widget.vorhanden?.icsUrl ?? '');
  late String _farbwert = widget.vorhanden?.color ?? '#3B82F6';

  bool _speichert = false;
  String? _fehler;

  @override
  void dispose() {
    _name.dispose();
    _ics.dispose();
    super.dispose();
  }

  Future<void> _speichern() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _speichert = true;
      _fehler = null;
    });
    try {
      final adresse = _ics.text.trim();
      if (widget.vorhanden == null) {
        await CalendarService.anlegen(
            name: name, color: _farbwert, icsUrl: adresse);
      } else {
        await CalendarService.aendern(widget.vorhanden!.id,
            name: name, color: _farbwert, icsUrl: adresse);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _speichert = false;
        _fehler = ApiFehler.text(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = widget.vorhanden == null;
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(neu ? 'Neuer Kalender' : 'Kalender ändern'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'z. B. Müllabfuhr',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                    backgroundColor: _farbe(_farbwert), radius: 14),
                title: const Text('Farbe'),
                subtitle: Text(_farbwert),
                trailing: const Icon(Icons.palette_outlined),
                onTap: () async {
                  final gewaehlt =
                      await ColorPickerDialog.show(context, _farbwert);
                  if (gewaehlt != null) setState(() => _farbwert = gewaehlt);
                },
              ),
              const Divider(height: 28),
              TextField(
                controller: _ics,
                decoration: const InputDecoration(
                  labelText: 'ICS-Adresse (optional)',
                  hintText: 'https://…/abfuhrtermine.ics',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mit Adresse wird der Kalender regelmäßig geholt — für '
                'Müllabfuhr, Feiertage oder Schulferien. Ohne Adresse trägst '
                'du die Termine selbst ein.',
                style: TextStyle(
                    fontSize: 12, color: colors.onSurfaceVariant, height: 1.4),
              ),
              if (_fehler != null) ...[
                const SizedBox(height: 16),
                Text(_fehler!, style: TextStyle(color: colors.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _speichert ? null : () => Navigator.pop(context, false),
            child: const Text('Abbrechen')),
        FilledButton(
          onPressed: (_speichert || _name.text.trim().isEmpty)
              ? null
              : _speichern,
          child: Text(neu ? 'Anlegen' : 'Speichern'),
        ),
      ],
    );
  }
}


// ── .ics in diesen Kalender ─────────────────────────────────────────────

class _ImportDialog extends StatefulWidget {
  final Kalender kalender;
  const _ImportDialog({required this.kalender});

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _inhalt = TextEditingController();
  final _adresse = TextEditingController();

  List<PlannerEntryType> _typen = [];
  int? _typ;
  bool _laedt = true;
  bool _arbeitet = false;
  String? _fehler;

  @override
  void initState() {
    super.initState();
    _typenLaden();
  }

  Future<void> _typenLaden() async {
    try {
      final typen = await PlannerService.loadTypes();
      if (!mounted) return;
      setState(() {
        _typen = typen;
        _typ = typen.isEmpty ? null : typen.first.id;
        _laedt = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _laedt = false;
        _fehler = 'Die Terminarten konnten nicht geladen werden.';
      });
    }
  }

  @override
  void dispose() {
    _inhalt.dispose();
    _adresse.dispose();
    super.dispose();
  }

  Future<void> _einlesen() async {
    if (_typ == null) return;
    setState(() {
      _arbeitet = true;
      _fehler = null;
    });
    try {
      final antwort = await PlannerService.importieren(
        typeId: _typ!,
        ics: _inhalt.text.trim(),
        url: _adresse.text.trim(),
        calendarId: widget.kalender.id,
        color: widget.kalender.color,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${antwort['imported'] ?? 0} Termine eingelesen, '
            '${antwort['updated'] ?? 0} aktualisiert.'),
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _arbeitet = false;
        _fehler = ApiFehler.text(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final etwasDa =
        _inhalt.text.trim().isNotEmpty || _adresse.text.trim().isNotEmpty;

    if (_laedt) {
      return const AlertDialog(
        content: SizedBox(
            height: 80, child: Center(child: CircularProgressIndicator())),
      );
    }

    return AlertDialog(
      title: Text('Termine in „${widget.kalender.name}"'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Einmalig einlesen — anders als das Abonnement, das sich '
                'regelmäßig selbst holt. Entweder eine Adresse angeben oder '
                'den Inhalt einer .ics-Datei hineinkopieren.',
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _adresse,
                decoration: const InputDecoration(
                  labelText: 'Adresse (.ics)',
                  hintText: 'https://…/termine.ics',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _inhalt,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'oder Inhalt der Datei',
                  hintText: 'BEGIN:VCALENDAR …',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_typen.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _typ,
                  decoration: const InputDecoration(
                      labelText: 'Als welche Terminart?'),
                  items: [
                    for (final t in _typen)
                      DropdownMenuItem(value: t.id, child: Text(t.name)),
                  ],
                  onChanged: (v) => setState(() => _typ = v),
                ),
              ],
              if (_fehler != null) ...[
                const SizedBox(height: 16),
                Text(_fehler!, style: TextStyle(color: colors.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _arbeitet ? null : () => Navigator.pop(context, false),
            child: const Text('Abbrechen')),
        FilledButton(
          onPressed: (_arbeitet || !etwasDa || _typ == null) ? null : _einlesen,
          child: const Text('Einlesen'),
        ),
      ],
    );
  }
}

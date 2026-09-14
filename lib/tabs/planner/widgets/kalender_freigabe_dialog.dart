import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/kalender.dart';
import 'package:productivity/dataclasses/kalender_freigabe.dart';
import 'package:productivity/dataclasses/planner_entry_type.dart';
import 'package:productivity/dataclasses/user.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/dataservice/calendar_service.dart';
import 'package:productivity/dataservice/planner_service.dart';
import 'package:productivity/dataservice/user_service.dart';

/// Wer diesen Kalender lesen darf.
///
/// Standardmäßig sieht niemand einen fremden Kalender. Wer soll, wird hier
/// eingeladen — wahlweise nur für bestimmte Termintypen, ein Stichwort im
/// Titel oder beides.
///
/// Zwei Dinge, die die Oberfläche sagen muss, weil sie sonst niemand
/// ahnt:
///
/// * **Private Termine bleiben außen vor**, auch nach einer Freigabe.
/// * Der Eingeladene entscheidet **selbst**, ob der Kalender bei ihm
///   auftaucht — über dieselbe Kalenderfilterung wie bei den eigenen.
class KalenderFreigabeDialog extends StatefulWidget {
  final Kalender kalender;
  const KalenderFreigabeDialog({super.key, required this.kalender});

  @override
  State<KalenderFreigabeDialog> createState() => _KalenderFreigabeDialogState();
}

class _KalenderFreigabeDialogState extends State<KalenderFreigabeDialog> {
  List<KalenderFreigabe> _freigaben = [];
  List<User> _personen = [];
  List<PlannerEntryType> _typen = [];
  bool _laedt = true;
  String? _fehler;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    setState(() {
      _laedt = true;
      _fehler = null;
    });
    try {
      // Die drei zusammen: die Liste ist ohne Personen und Typen nicht
      // vollständig darstellbar, und drei Ladezustände nacheinander wären
      // nur Flackern.
      final ergebnis = await Future.wait([
        CalendarService.freigaben(widget.kalender.id),
        UserService.getAllUsers(),
        PlannerService.loadTypes(),
      ]);
      if (!mounted) return;
      setState(() {
        _freigaben = ergebnis[0] as List<KalenderFreigabe>;
        _personen = ergebnis[1] as List<User>;
        _typen = ergebnis[2] as List<PlannerEntryType>;
        _laedt = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _laedt = false;
        _fehler = ApiFehler.text(e);
      });
    }
  }

  /// Wer noch nicht eingeladen ist — und nie man selbst.
  List<User> get _offen {
    final schon = _freigaben.map((f) => f.userId).toSet();
    return _personen
        .where((u) => u.id != widget.kalender.ownerId && !schon.contains(u.id))
        .toList();
  }

  String _name(User u) {
    final voll = '${u.firstname} ${u.lastname}'.trim();
    return voll.isEmpty ? u.username : voll;
  }

  Future<void> _hinzufuegen() async {
    final person = await showDialog<User>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Wen einladen?'),
        children: [
          for (final u in _offen)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, u),
              child: Text(_name(u)),
            ),
          if (_offen.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Text('Alle sind schon eingeladen.'),
            ),
        ],
      ),
    );
    if (person == null || !mounted) return;
    await _filterBearbeiten(userId: person.id, name: _name(person));
  }

  Future<void> _filterBearbeiten({
    required String userId,
    required String name,
    KalenderFreigabe? vorhanden,
  }) async {
    final ergebnis = await showDialog<_FilterWahl>(
      context: context,
      builder: (_) => _FilterDialog(
        name: name,
        typen: _typen,
        gewaehlteTypen: vorhanden?.typIds ?? const [],
        stichwort: vorhanden?.stichwort ?? '',
      ),
    );
    if (ergebnis == null) return;
    try {
      await CalendarService.freigeben(
        widget.kalender.id,
        userId: userId,
        typIds: ergebnis.typIds,
        stichwort: ergebnis.stichwort,
      );
      await _laden();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ApiFehler.text(e))));
    }
  }

  Future<void> _entziehen(KalenderFreigabe f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${f.userName} aussperren?'),
        content: Text(
          '${f.userName} sieht „${widget.kalender.name}" danach nicht mehr. '
          'Termine werden dabei nicht gelöscht.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Zurücknehmen')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CalendarService.freigabeEntziehen(widget.kalender.id, f.userId);
      await _laden();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ApiFehler.text(e))));
    }
  }

  /// „Arbeit, Sport · enthält „Projekt"" — oder „alles außer Privatem".
  String _filterText(KalenderFreigabe f) {
    if (!f.hatFilter) return 'alles außer Privatem';
    final teile = <String>[];
    if (f.typIds.isNotEmpty) {
      final namen = _typen
          .where((t) => f.typIds.contains(t.id))
          .map((t) => t.name)
          .toList();
      // Ein Typ, den es nicht mehr gibt, soll die Zeile nicht verstummen
      // lassen – dann steht dort wenigstens die Anzahl.
      teile.add(namen.isEmpty ? '${f.typIds.length} Typen' : namen.join(', '));
    }
    if (f.stichwort != null) teile.add('enthält „${f.stichwort}"');
    return teile.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text('„${widget.kalender.name}" freigeben'),
      content: SizedBox(
        width: 420,
        child: _laedt
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            : _fehler != null
                ? Text(_fehler!)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Ohne Freigabe sieht niemand deinen Kalender. '
                        'Private Termine bleiben auch danach verborgen — '
                        'die sieht nur du.',
                        style: text.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      if (_freigaben.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'Noch niemand.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        )
                      else
                        Flexible(
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              for (final f in _freigaben)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.person_outline),
                                  title: Text(f.userName),
                                  subtitle: Text(_filterText(f),
                                      style: text.bodySmall),
                                  onTap: () => _filterBearbeiten(
                                    userId: f.userId,
                                    name: f.userName,
                                    vorhanden: f,
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(Icons.close_rounded,
                                        color: colors.error),
                                    tooltip: 'Freigabe zurücknehmen',
                                    onPressed: () => _entziehen(f),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Ob der Kalender bei ihnen auftaucht, entscheiden '
                        'sie selbst — über ihre eigene Kalenderauswahl.',
                        style: text.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
      ),
      actions: [
        if (!_laedt && _fehler == null)
          TextButton.icon(
            onPressed: _hinzufuegen,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Einladen'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fertig'),
        ),
      ],
    );
  }
}

/// Was der Eingeladene sehen darf.
class _FilterWahl {
  final List<int> typIds;
  final String stichwort;
  const _FilterWahl(this.typIds, this.stichwort);
}

class _FilterDialog extends StatefulWidget {
  final String name;
  final List<PlannerEntryType> typen;
  final List<int> gewaehlteTypen;
  final String stichwort;

  const _FilterDialog({
    required this.name,
    required this.typen,
    required this.gewaehlteTypen,
    required this.stichwort,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late final Set<int> _typen = widget.gewaehlteTypen.toSet();
  late final TextEditingController _stichwort =
      TextEditingController(text: widget.stichwort);

  @override
  void dispose() {
    _stichwort.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text('Was sieht ${widget.name}?'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nichts ausgewählt heißt: alles aus diesem Kalender, '
                'außer Privatem.',
                style:
                    text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Text('Termintypen', style: text.titleSmall),
              const SizedBox(height: 8),
              if (widget.typen.isEmpty)
                Text('Noch keine Typen angelegt.',
                    style: text.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final t in widget.typen)
                      FilterChip(
                        label: Text(t.name),
                        selected: _typen.contains(t.id),
                        onSelected: (an) => setState(
                            () => an ? _typen.add(t.id) : _typen.remove(t.id)),
                      ),
                  ],
                ),
              const SizedBox(height: 20),
              Text('Stichwort im Titel', style: text.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _stichwort,
                decoration: const InputDecoration(
                  hintText: 'z. B. Fußball',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Beides zusammen wirkt als UND: nur Termine, die zum Typ '
                'passen und das Stichwort tragen.',
                style:
                    text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
              context, _FilterWahl(_typen.toList(), _stichwort.text)),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}

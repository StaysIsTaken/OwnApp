import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/haushalt.dart';
import 'package:productivity/dataclasses/kalender.dart';
import 'package:productivity/dataclasses/user.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/dataservice/calendar_service.dart';
import 'package:productivity/dataservice/haushalt_service.dart';
import 'package:productivity/dataservice/haushalt_sicht.dart';
import 'package:productivity/dataservice/user_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/provider/haushalt_provider.dart';
import 'package:productivity/provider/permission_provider.dart';
import 'package:productivity/provider/user_provider.dart';
import 'package:productivity/tabs/haushalt/einladung_dialog.dart';
import 'package:provider/provider.dart';

/// Der Haushalt: anlegen, einladen, Mitglieder, austreten.
///
/// Diese Seite hat **drei Gesichter**, und das ist kein Zufall, sondern
/// das Leitprinzip:
///
/// * **Kein Haushalt, keine Einladung** — ein Satz, was ein Haushalt ist,
///   und ein Knopf. Sonst nichts.
/// * **Eine Einladung liegt vor** — die Frage, samt Pop-up.
/// * **Im Haushalt** — Mitglieder, Einladungen, und was jedes Mitglied
///   für sich entscheidet: Finanz-Sichtbarkeit, Assistenten-Freigabe und
///   **welche der eigenen Kalender die anderen mitlesen dürfen**.
///
/// Der Kalenderabschnitt am Ende führt zwei Dinge zusammen, die sich
/// ähnlich anfühlen und verschieden sind — „mein Kalender, aber ihr dürft
/// mitlesen" und „unser Kalender". Beides steht nebeneinander, weil man
/// sich sonst für eins von beidem hält.
///
/// Wer in keinem Haushalt ist, kommt hierher nur über die Einstellungen.
/// Im Menü taucht der Bereich erst auf, wenn es etwas zu sehen gibt.
class HaushaltPage extends BasePage {
  const HaushaltPage({super.key}) : super(title: 'Haushalt');

  @override
  Widget buildBody(BuildContext context) => const _Haushalt();
}

class _Haushalt extends StatefulWidget {
  const _Haushalt();

  @override
  State<_Haushalt> createState() => _HaushaltState();
}

class _HaushaltState extends State<_Haushalt> {
  List<User> _leute = [];
  List<Einladung> _gesendet = const [];
  List<Kalender> _kalender = const [];
  bool _laedt = true;
  String? _fehler;

  /// Meine persönlichen Kalender — die, für die ich den Schalter stellen
  /// darf. Der gemeinsame steht hier nicht: ihn sehen ohnehin alle.
  List<Kalender> get _meineKalender => _kalender
      .where((k) => k.gehoert(_ichId) && !k.istHaushaltskalender)
      .toList();

  List<Kalender> get _gemeinsameKalender =>
      _kalender.where((k) => k.istHaushaltskalender).toList();

  @override
  void initState() {
    super.initState();
    _laden();
  }

  HaushaltProvider get _provider =>
      Provider.of<HaushaltProvider>(context, listen: false);

  String get _ichId =>
      Provider.of<UserProvider>(context, listen: false).user?.id ?? '';

  bool get _darfVerwalten =>
      Provider.of<PermissionProvider>(context, listen: false)
          .darf('household:manage');

  Future<void> _laden() async {
    setState(() {
      _laedt = true;
      _fehler = null;
    });
    try {
      await _provider.laden();

      // Die Namensliste und die gesendeten Einladungen dürfen ausfallen:
      // ohne sie kann man niemanden einladen, aber der Haushalt steht
      // trotzdem da.
      List<User> leute = const [];
      List<Einladung> gesendet = const [];
      List<Kalender> kalender = const [];
      try {
        leute = await UserService.getAllUsers();
      } catch (_) {
        leute = const [];
      }
      // Wie die Namensliste: darf ausfallen. Wem „planner:read" fehlt,
      // der sieht den Kalenderabschnitt nicht — und den Rest des
      // Haushalts trotzdem.
      if (_provider.imHaushalt) {
        try {
          kalender = await CalendarService.laden();
        } catch (_) {
          kalender = const [];
        }
      }
      if (_provider.imHaushalt && _darfVerwalten) {
        try {
          gesendet = await HaushaltService.gesendeteEinladungen();
        } catch (_) {
          gesendet = const [];
        }
      }
      if (!mounted) return;
      setState(() {
        _leute = leute;
        _gesendet = gesendet;
        _kalender = kalender;
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

  void _melde(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ── Handlungen ─────────────────────────────────────────────────────────

  Future<void> _anlegen() async {
    final name = await _NameDialog.zeige(context,
        titel: 'Haushalt anlegen', knopf: 'Anlegen');
    if (name == null) return;
    try {
      await HaushaltService.anlegen(name);
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _umbenennen(Haushalt haushalt) async {
    final name = await _NameDialog.zeige(context,
        titel: 'Haushalt umbenennen',
        knopf: 'Übernehmen',
        vorgabe: haushalt.name);
    if (name == null) return;
    try {
      await HaushaltService.aendern(name: name);
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _einladen(Haushalt haushalt) async {
    final drin = {for (final m in haushalt.mitglieder) m.userId};
    final gefragt = {for (final e in _gesendet) e.userId};
    final offen =
        _leute.where((u) => !drin.contains(u.id) && !gefragt.contains(u.id));

    if (offen.isEmpty) {
      _melde('Es gibt niemanden mehr, den du einladen könntest.');
      return;
    }

    final wahl = await showModalBottomSheet<User>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Wen einladen?'),
              subtitle: Text('Eingeladen wird, wer schon ein Konto hat.'),
            ),
            const Divider(height: 1),
            for (final u in offen)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text('${u.firstname} ${u.lastname}'.trim()),
                onTap: () => Navigator.pop(context, u),
              ),
          ],
        ),
      ),
    );
    if (wahl == null) return;

    try {
      await HaushaltService.einladen(wahl.id);
      await _laden();
      if (mounted) _melde('Einladung ist raus.');
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _annehmen(Einladung einladung) async {
    // Das Pop-up ist nicht überspringbar: hier führt kein Weg am Dialog
    // vorbei, und die Stufe geht ausdrücklich mit.
    final stufe = await EinladungDialog.zeige(context, einladung: einladung);
    if (stufe == null) return;
    try {
      await HaushaltService.annehmen(einladung.id, stufe);
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _ablehnen(Einladung einladung) async {
    try {
      await HaushaltService.ablehnen(einladung.id);
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _zurueckziehen(Einladung einladung) async {
    try {
      await HaushaltService.zurueckziehen(einladung.id);
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _stufeAendern(Mitglied ich) async {
    final stufe =
        await FinanzsichtDialog.zeige(context, aktuell: ich.finanzsicht);
    if (stufe == null) return;
    try {
      await HaushaltService.finanzsicht(stufe);
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  /// Meine Beiträge für die Assistenten-Zugänge der anderen freigeben.
  ///
  /// Das ist nur die eine Hälfte: ob die gemeinsamen Sachen wirklich
  /// hinausgehen, entscheidet zusätzlich der Haushalts-Ast im Zugang
  /// desjenigen, der ihn benutzt. Die Freigabe sagt „von mir aus".
  Future<void> _freigabeAendern(bool frei) async {
    try {
      await HaushaltService.mcpFreigabe(frei);
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  /// Einen meiner Kalender den anderen im Haushalt zu lesen geben.
  ///
  /// Je Kalender und nicht als ein Schalter für alle: der Arbeitskalender
  /// darf mitlaufen, während der eine daneben es nicht soll. Ein Schalter
  /// für alles wäre die Entscheidung, die niemand trifft — man ließe ihn
  /// dann aus.
  Future<void> _kalenderFreigabe(Kalender k, bool frei) async {
    // Vorweg umlegen, damit der Schalter nicht erst nach der Antwort
    // umspringt. Geht es schief, holt [_laden] den Wahrheitsstand.
    setState(() {
      _kalender = [
        for (final vorhanden in _kalender)
          if (vorhanden.id == k.id)
            Kalender(
              id: k.id, ownerId: k.ownerId, ownerName: k.ownerName,
              name: k.name, color: k.color, icon: k.icon,
              istStandard: k.istStandard, icsUrl: k.icsUrl,
              zuletztGeholt: k.zuletztGeholt, anzahlTermine: k.anzahlTermine,
              haushaltId: k.haushaltId,
              istHaushaltskalender: k.istHaushaltskalender,
              haushaltsFreigabe: frei,
              darfSchreiben: k.darfSchreiben, darfVerwalten: k.darfVerwalten,
            )
          else
            vorhanden,
      ];
    });
    try {
      await CalendarService.haushaltsFreigabe(k.id, frei);
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
    await _laden();
  }

  /// Einen Kalender anlegen, der dem Haushalt gehört.
  ///
  /// Kein Besitzer, kein „gehört Lisa" — jedes Mitglied sieht ihn und
  /// trägt darin ein. Das ist der andere Fall neben der Freigabe, und
  /// deshalb steht er direkt daneben.
  Future<void> _gemeinsamenAnlegen() async {
    final name = await _NameDialog.zeige(context,
        titel: 'Gemeinsamer Kalender',
        knopf: 'Anlegen',
        hinweis: 'Familie');
    if (name == null) return;
    try {
      await CalendarService.anlegen(name: name, unseres: true);
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _gemeinsamenLoeschen(Kalender k) async {
    final ja = await _fragen(
      '„${k.name}" löschen?',
      'Die Termine darin bleiben erhalten — sie verlieren nur ihre '
          'Zuordnung und stehen danach in keinem Kalender mehr. '
          'Löschen darf ihn, wer den Haushalt führt.',
    );
    if (!ja) return;
    try {
      await CalendarService.loeschen(k.id);
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _uebergeben(Haushalt haushalt) async {
    final andere =
        haushalt.mitglieder.where((m) => m.userId != _ichId).toList();
    if (andere.isEmpty) return;

    final wahl = await showModalBottomSheet<Mitglied>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Wer führt den Haushalt ab jetzt?'),
              subtitle: Text(
                  'Er darf dann einladen, umbenennen und auflösen.'),
            ),
            const Divider(height: 1),
            for (final m in andere)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(m.name),
                onTap: () => Navigator.pop(context, m),
              ),
          ],
        ),
      ),
    );
    if (wahl == null) return;

    try {
      await HaushaltService.uebergeben(wahl.userId);
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _entfernen(Mitglied m) async {
    final ja = await _fragen(
      'Aus dem Haushalt entfernen?',
      '${m.name} sieht danach nur noch seine eigenen Sachen. '
          'Was dem Haushalt gehört, bleibt beim Haushalt.',
    );
    if (!ja) return;
    try {
      await HaushaltService.entfernen(m.userId);
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _austreten(Haushalt haushalt) async {
    if (!Haushaltssicht.darfGehen(haushalt, _ichId)) {
      _melde(Haushaltssicht.warumNichtGehen);
      return;
    }
    final allein = haushalt.mitglieder.length <= 1;
    final ja = await _fragen(
      allein ? 'Haushalt auflösen?' : 'Haushalt verlassen?',
      allein
          ? 'Du bist der letzte. Der Haushalt löst sich auf — Rezepte, '
              'Vorrat und Preise bleiben und gehören danach dir.'
          : 'Deine eigenen Sachen bleiben deine. Was dem Haushalt gehört, '
              'bleibt beim Haushalt.',
    );
    if (!ja) return;
    try {
      await HaushaltService.austreten();
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<void> _aufloesen(Haushalt haushalt) async {
    final ja = await _fragen(
      'Haushalt auflösen?',
      'Rezepte, Vorrat, Preise und Essensplan werden nicht gelöscht — '
          'sie verlieren nur ihre Zuordnung und gehören danach dir. '
          'Die anderen ${haushalt.mitglieder.length - 1} sehen sie dann '
          'nicht mehr.',
    );
    if (!ja) return;
    try {
      await HaushaltService.aufloesen();
      await _laden();
    } catch (e) {
      if (mounted) _melde(ApiFehler.text(e));
    }
  }

  Future<bool> _fragen(String titel, String text) async {
    final ja = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titel),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ja'),
          ),
        ],
      ),
    );
    return ja ?? false;
  }

  // ── Aufbau ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_laedt) return const Center(child: CircularProgressIndicator());
    if (_fehler != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(_fehler!, textAlign: TextAlign.center),
        ),
      );
    }

    final haushalt = context.watch<HaushaltProvider>().haushalt;
    final einladungen = context.watch<HaushaltProvider>().einladungen;

    return RefreshIndicator(
      onRefresh: _laden,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
        children: [
          for (final e in einladungen) _einladungskarte(e),
          if (haushalt == null)
            _ohneHaushalt()
          else
            ..._mitHaushalt(haushalt),
        ],
      ),
    );
  }

  Widget _einladungskarte(Einladung e) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Einladung in „${e.haushaltName}"',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${e.vonName} möchte dich dabeihaben.'),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _ablehnen(e),
                  child: const Text('Ablehnen'),
                ),
                FilledButton(
                  onPressed: () => _annehmen(e),
                  child: const Text('Ansehen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ohneHaushalt() {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
      child: Column(
        children: [
          Icon(Icons.home_outlined, size: 64, color: colors.outline),
          const SizedBox(height: 16),
          Text('Noch kein Haushalt',
              style: text.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'In einem Haushalt teilt ihr Rezepte, Vorrat, Einkaufszettel '
            'und Essensplan. Was dir persönlich gehört, bleibt deins — '
            'ein Haushalt nimmt nichts weg, er kommt dazu.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          if (_darfVerwalten)
            FilledButton.icon(
              onPressed: _anlegen,
              icon: const Icon(Icons.add_home_outlined),
              label: const Text('Haushalt anlegen'),
            )
          else
            Text(
              'Zum Anlegen fehlt dir das Recht „household:manage". '
              'Einladen kann dich trotzdem jeder.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  List<Widget> _mitHaushalt(Haushalt haushalt) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final ich = _ichId;
    final meiner = haushalt.gehoert(ich);
    final ichAlsMitglied = haushalt.mitglied(ich);

    return [
      Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: const Icon(Icons.home_rounded),
          title: Text(haushalt.name,
              style: text.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${Haushaltssicht.mitgliederSatz(haushalt)} · '
            'geführt von ${haushalt.ownerName}',
          ),
          trailing: meiner && _darfVerwalten
              ? IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Umbenennen',
                  onPressed: () => _umbenennen(haushalt),
                )
              : null,
        ),
      ),

      _ueberschrift('MITGLIEDER'),
      for (final m in haushalt.mitglieder)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(m.istBesitzer
                ? Icons.shield_outlined
                : Icons.person_outline),
            title: Text(m.userId == ich ? '${m.name} (du)' : m.name),
            subtitle: Text(
              m.istBesitzer ? 'Führt den Haushalt' : 'Mitglied',
            ),
            // Die Stufe der anderen steht da, die Zahlen dahinter nicht:
            // sie sollen wissen, warum bei jemandem keine Zahl auftaucht.
            trailing: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(m.finanzsicht.titel,
                      style: text.labelSmall),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: colors.outlineVariant),
                ),
                if (meiner && m.userId != ich && _darfVerwalten)
                  IconButton(
                    icon: const Icon(Icons.person_remove_outlined),
                    tooltip: 'Entfernen',
                    onPressed: () => _entfernen(m),
                  ),
              ],
            ),
          ),
        ),

      if (ichAlsMitglied != null) ...[
        const SizedBox(height: 8),
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('Deine Finanzen im Haushalt'),
            subtitle: Text(ichAlsMitglied.finanzsicht.erklaerung),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _stufeAendern(ichAlsMitglied),
          ),
        ),

        // Die zweite Entscheidung, die jedes Mitglied fuer sich trifft.
        // Sie steht hier und nicht in den MCP-Einstellungen, weil sie
        // den HAUSHALT betrifft und nicht den eigenen Zugang: es geht um
        // die eigenen Beitraege in den Zugaengen der ANDEREN.
        Card(
          margin: const EdgeInsets.only(bottom: 4),
          child: SwitchListTile(
            secondary: const Icon(Icons.hub_outlined),
            title: const Text('Deine Beiträge für Assistenten'),
            subtitle: Text(
              ichAlsMitglied.mcpFreigabe
                  ? 'Was du zu unseren Rezepten, Listen und Vorräten '
                      'beigetragen hast, darf in die Assistenten-Zugänge '
                      'der anderen.'
                  : 'Deine Beiträge bleiben drinnen — auch wenn jemand '
                      'anderes den Haushalt in seinem Zugang anschaltet.',
            ),
            value: ichAlsMitglied.mcpFreigabe,
            onChanged: _freigabeAendern,
          ),
        ),
        // Wer gemeinsame Daten weitergibt, tut das mit den Beitraegen
        // der anderen. Also steht hier, wer freigibt -- derselbe Gedanke
        // wie „2 von 3 rechnen mit".
        if (Haushaltssicht.freigabeSatz(haushalt.mitglieder).isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              Haushaltssicht.freigabeSatz(haushalt.mitglieder),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],

      ..._kalenderabschnitt(haushalt),

      if (meiner && _darfVerwalten) ...[
        _ueberschrift('EINLADUNGEN'),
        for (final e in _gesendet)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.mail_outline),
              title: Text(e.userName),
              subtitle: const Text('Wartet auf Antwort'),
              trailing: IconButton(
                icon: const Icon(Icons.undo_rounded),
                tooltip: 'Zurückziehen',
                onPressed: () => _zurueckziehen(e),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: OutlinedButton.icon(
            onPressed: () => _einladen(haushalt),
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Jemanden einladen'),
          ),
        ),
      ],

      const SizedBox(height: 8),
      if (meiner && haushalt.mitglieder.length > 1) ...[
        OutlinedButton.icon(
          onPressed: () => _uebergeben(haushalt),
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Haushalt übergeben'),
        ),
        const SizedBox(height: 8),
        // Auflösen steht nur beim Besitzer, und nur wenn er nicht ohnehin
        // allein ist -- allein ist „Verlassen" dasselbe und heißt
        // verständlicher.
        if (_darfVerwalten)
          TextButton.icon(
            onPressed: () => _aufloesen(haushalt),
            icon: Icon(Icons.delete_outline, color: colors.error),
            label: Text('Haushalt auflösen',
                style: TextStyle(color: colors.error)),
          ),
      ] else
        OutlinedButton.icon(
          onPressed: () => _austreten(haushalt),
          icon: const Icon(Icons.logout_rounded),
          label: Text(haushalt.mitglieder.length <= 1
              ? 'Haushalt auflösen'
              : 'Haushalt verlassen'),
        ),
      if (meiner && haushalt.mitglieder.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            Haushaltssicht.warumNichtGehen,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
    ];
  }

  /// Kalender im Haushalt — zwei Dinge, die sich ähnlich anfühlen.
  ///
  /// **„Meine Kalender"** ist eine Entscheidung über mich: welche meiner
  /// Kalender die anderen mitlesen dürfen. Sie steht deshalb neben der
  /// Finanz-Stufe und der Assistenten-Freigabe, in demselben Abschnitt
  /// „was ich für mich entscheide".
  ///
  /// **„Gemeinsame Kalender"** ist etwas anderes: ein Kalender, der
  /// niemandem gehört. Beides nebeneinander, weil man sonst das eine für
  /// das andere hält und sich wundert, warum der Familienkalender bei
  /// jedem anders heißt.
  ///
  /// Ohne Kalenderrechte fällt der ganze Abschnitt weg — wie überall in
  /// dieser App: ein leerer Abschnitt ist schlechter als keiner.
  List<Widget> _kalenderabschnitt(Haushalt haushalt) {
    if (_kalender.isEmpty) return const [];

    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final meine = _meineKalender;
    final gemeinsame = _gemeinsameKalender;
    final fuehrer = haushalt.gehoert(_ichId);
    final wieviele = meine.where((k) => k.haushaltsFreigabe).length;

    return [
      if (meine.isNotEmpty) ...[
        _ueberschrift('MEINE KALENDER IM HAUSHALT'),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            Haushaltssicht.kalenderSatz(
                frei: wieviele, gesamt: meine.length),
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        for (final k in meine)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: SwitchListTile(
              secondary: CircleAvatar(
                  backgroundColor: _farbe(k.color), radius: 12),
              title: Text(k.name),
              subtitle: Text(
                k.haushaltsFreigabe
                    ? 'Alle im Haushalt sehen die Termine darin.'
                    : 'Nur du siehst die Termine darin.',
              ),
              value: k.haushaltsFreigabe,
              onChanged: (frei) => _kalenderFreigabe(k, frei),
            ),
          ),
        // Der Satz, den man sonst nirgends findet und der die häufigste
        // Rückfrage vorwegnimmt.
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text(
            'Als privat markierte Termine bleiben privat — auch in einem '
            'freigegebenen Kalender, und auch im gemeinsamen.',
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      ],

      _ueberschrift('GEMEINSAME KALENDER'),
      if (gemeinsame.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            'Ein gemeinsamer Kalender gehört keinem von euch. Jeder sieht '
            'ihn, jeder trägt darin ein — für alles, was den ganzen '
            'Haushalt angeht.',
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        )
      else
        for (final k in gemeinsame)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading:
                  CircleAvatar(backgroundColor: _farbe(k.color), radius: 14),
              title: Text(k.name),
              subtitle: Text(
                '${k.anzahlTermine} '
                '${k.anzahlTermine == 1 ? "Termin" : "Termine"} · '
                'gehört ${haushalt.name}',
              ),
              // Löschen darf nur, wer den Haushalt führt: umbenennen sieht
              // jeder, aber nach dem Löschen stehen die Termine eines
              // halben Jahres in keinem Kalender mehr.
              trailing: fuehrer
                  ? IconButton(
                      icon: Icon(Icons.delete_outline, color: colors.error),
                      tooltip: 'Löschen',
                      onPressed: () => _gemeinsamenLoeschen(k),
                    )
                  : null,
            ),
          ),
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: OutlinedButton.icon(
          onPressed: _gemeinsamenAnlegen,
          icon: const Icon(Icons.calendar_month_outlined),
          label: const Text('Gemeinsamen Kalender anlegen'),
        ),
      ),
    ];
  }

  static Color _farbe(String hex) {
    final wert = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return wert == null ? const Color(0xFF3B82F6) : Color(0xFF000000 | wert);
  }

  Widget _ueberschrift(String titel) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
        child: Text(
          titel,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
}

/// Name eingeben — zum Anlegen und zum Umbenennen.
class _NameDialog extends StatefulWidget {
  final String titel;
  final String knopf;
  final String vorgabe;

  /// Der graue Beispielname im Feld. „Zuhause" passt zum Haushalt,
  /// „Familie" zum gemeinsamen Kalender — derselbe Dialog, ein anderes
  /// Beispiel.
  final String hinweis;

  const _NameDialog({
    required this.titel,
    required this.knopf,
    this.vorgabe = '',
    this.hinweis = 'Zuhause',
  });

  static Future<String?> zeige(
    BuildContext context, {
    required String titel,
    required String knopf,
    String vorgabe = '',
    String hinweis = 'Zuhause',
  }) =>
      showDialog<String>(
        context: context,
        builder: (_) => _NameDialog(
            titel: titel, knopf: knopf, vorgabe: vorgabe, hinweis: hinweis),
      );

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.vorgabe);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titel),
      content: TextField(
        controller: _name,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Name',
          hintText: widget.hinweis,
        ),
        onSubmitted: (_) => _fertig(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _fertig, child: Text(widget.knopf)),
      ],
    );
  }

  void _fertig() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }
}

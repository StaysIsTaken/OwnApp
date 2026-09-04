import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/admin.dart';
import 'package:productivity/dataservice/admin_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/tabs/admin/role_editor.dart';
import 'package:productivity/tabs/admin/passwort_dialog.dart';
import 'package:productivity/tabs/admin/user_editor.dart';
import 'package:productivity/tabs/admin/user_roles_sheet.dart';

/// Adminbereich: wer ist da, wer darf was.
///
/// Zwei Reiter, weil es zwei getrennte Fragen sind — und im Backend auch
/// zwei getrennte Rechte (`admin:users`, `admin:roles`).
class AdminPage extends BasePage {
  const AdminPage({super.key}) : super(title: 'Verwaltung');

  @override
  Widget buildBody(BuildContext context) => const _AdminContent();
}

class _AdminContent extends StatefulWidget {
  const _AdminContent();

  @override
  State<_AdminContent> createState() => _AdminContentState();
}

class _AdminContentState extends State<_AdminContent>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  List<AdminBenutzer> _benutzer = [];
  List<Rolle> _rollen = [];
  List<Recht> _katalog = [];
  bool _laedt = true;
  String? _fehler;

  /// Der Online-Stand veraltet still — deshalb wird er nachgeladen, solange
  /// die Seite offen ist. 15 Sekunden sind oft genug, um Kommen und Gehen zu
  /// sehen, und selten genug, um niemandem zur Last zu fallen.
  Timer? _auffrischen;

  @override
  void initState() {
    super.initState();
    _laden();
    _auffrischen = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _benutzerNachladen(),
    );
  }

  @override
  void dispose() {
    _auffrischen?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _laden() async {
    setState(() {
      _laedt = true;
      _fehler = null;
    });
    try {
      final benutzer = await AdminService.benutzer();
      final rollen = await AdminService.rollen();
      final katalog = await AdminService.rechteKatalog();
      if (!mounted) return;
      setState(() {
        _benutzer = benutzer;
        _rollen = rollen;
        _katalog = katalog;
        _laedt = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _laedt = false;
        _fehler = e.response?.statusCode == 403
            ? 'Dafür fehlt dir die Berechtigung.'
            : 'Die Verwaltung konnte nicht geladen werden.';
      });
    }
  }

  /// Nur die Benutzer — für den Takt im Hintergrund. Rollen und Katalog
  /// ändern sich nicht von allein, die müssen nicht mitlaufen.
  Future<void> _benutzerNachladen() async {
    try {
      final benutzer = await AdminService.benutzer();
      if (!mounted) return;
      setState(() => _benutzer = benutzer);
    } on DioException {
      // Ein misslungener Takt im Hintergrund darf die Seite nicht stören.
    }
  }

  void _melde(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  /// Fasst die Antwort des Servers in einen Satz. Gerade 409 ist hier
  /// wichtig: das ist die Aussperr-Sicherung, und die soll man verstehen.
  String _fehlertext(DioException e) {
    final detail = e.response?.data;
    if (detail is Map && detail['detail'] is String) {
      return detail['detail'] as String;
    }
    return 'Das hat nicht geklappt.';
  }

  @override
  Widget build(BuildContext context) {
    if (_laedt) return const Center(child: CircularProgressIndicator());
    if (_fehler != null) {
      return _Hinweis(icon: Icons.lock_outline, text: _fehler!);
    }

    return Column(
      children: [
        TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Benutzer (${_benutzer.length})'),
            Tab(text: 'Rollen (${_rollen.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [_benutzerListe(), _rollenListe()],
          ),
        ),
      ],
    );
  }

  // ── Benutzer ───────────────────────────────────────────────────────────

  Widget _benutzerListe() {
    final online = _benutzer.where((b) => b.online).length;
    final gesperrt = _benutzer.where((b) => !b.aktiv).length;
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _laden,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  '$online von ${_benutzer.length} gerade online'
                  '${gesperrt > 0 ? " · $gesperrt deaktiviert" : ""}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              ..._benutzer.map(_benutzerKachel),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: _benutzerAnlegen,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Benutzer'),
          ),
        ),
      ],
    );
  }

  Widget _benutzerKachel(AdminBenutzer b) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _OnlinePunkt(
          online: b.online,
          verbindungen: b.verbindungen,
          initialen: _initialen(b),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                b.anzeigename,
                style: TextStyle(
                  color: b.aktiv ? null : scheme.outline,
                  decoration: b.aktiv ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
            if (!b.aktiv) ...[
              const SizedBox(width: 8),
              Chip(
                label: const Text('deaktiviert', style: TextStyle(fontSize: 10)),
                backgroundColor: scheme.surfaceContainerHighest,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('@${b.username} · ${_zuletzt(b)}'),
            const SizedBox(height: 6),
            if (b.rollen.isEmpty)
              Text(
                'Keine Rolle — sieht nichts',
                style: TextStyle(color: scheme.error, fontSize: 12),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final r in b.rollen)
                    Chip(
                      label: Text(r.name, style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (wahl) => _benutzerAktion(wahl, b),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'rollen', child: Text('Rollen ändern')),
            const PopupMenuItem(
                value: 'passwort', child: Text('Passwort zurücksetzen')),
            PopupMenuItem(
              value: 'aktiv',
              child: Text(b.aktiv ? 'Deaktivieren' : 'Wieder freigeben'),
            ),
            const PopupMenuItem(value: 'loeschen', child: Text('Löschen')),
          ],
        ),
        onTap: () => _rollenZuweisen(b),
      ),
    );
  }

  // ── Aktionen an einem Benutzer ─────────────────────────────────────────

  Future<void> _benutzerAktion(String wahl, AdminBenutzer b) async {
    switch (wahl) {
      case 'rollen':
        await _rollenZuweisen(b);
      case 'passwort':
        await _passwortSetzen(b);
      case 'aktiv':
        await _aktivUmschalten(b);
      case 'loeschen':
        await _benutzerLoeschen(b);
    }
  }

  Future<void> _benutzerAnlegen() async {
    final angelegt = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (_) => UserEditor(rollen: _rollen),
    );
    if (angelegt == true) {
      await _laden();
      _melde('Benutzer angelegt');
    }
  }

  Future<void> _passwortSetzen(AdminBenutzer b) async {
    final neu = await showDialog<String>(
      context: context,
      builder: (_) => PasswortDialog(name: b.anzeigename),
    );
    if (neu == null) return;
    try {
      await AdminService.passwortSetzen(b.id, neu);
      _melde('Neues Passwort für ${b.anzeigename} gesetzt');
    } on DioException catch (e) {
      _melde(_fehlertext(e));
    }
  }

  Future<void> _aktivUmschalten(AdminBenutzer b) async {
    if (b.aktiv) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${b.anzeigename} deaktivieren?'),
          content: const Text(
            'Das Konto kommt nicht mehr herein — auch eine offene Sitzung '
            'endet sofort. Aufgaben, Notizen und Zeiten bleiben erhalten.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Deaktivieren')),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await AdminService.aktivSetzen(b.id, !b.aktiv);
      await _laden();
      _melde(b.aktiv
          ? '${b.anzeigename} ist deaktiviert'
          : '${b.anzeigename} ist wieder freigegeben');
    } on DioException catch (e) {
      _melde(_fehlertext(e));
    }
  }

  /// Zweistufig: der Server verweigert beim ersten Versuch, sobald noch
  /// Daten da sind, und sagt welche. Erst danach fragen wir wirklich nach.
  Future<void> _benutzerLoeschen(AdminBenutzer b) async {
    try {
      await AdminService.benutzerLoeschen(b.id);
      await _laden();
      _melde('${b.anzeigename} gelöscht');
      return;
    } on DioException catch (e) {
      final detail = e.response?.data is Map
          ? (e.response!.data as Map)['detail']
          : null;
      if (e.response?.statusCode != 409 || detail is! Map) {
        _melde(_fehlertext(e));
        return;
      }
      final bestand = (detail['data'] as Map?) ?? {};
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${b.anzeigename} wirklich löschen?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Das geht mit verloren:'),
              const SizedBox(height: 8),
              for (final e in bestand.entries)
                Text('· ${e.value}× ${_bestandName(e.key.toString())}'),
              const SizedBox(height: 12),
              const Text(
                'Deaktivieren erhält alles und macht nur den Zugang zu.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Endgültig löschen'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await AdminService.benutzerLoeschen(b.id, mitDaten: true);
        await _laden();
        _melde('${b.anzeigename} und alle Daten gelöscht');
      } on DioException catch (e2) {
        _melde(_fehlertext(e2));
      }
    }
  }

  /// Tabellennamen in etwas, das man lesen kann.
  String _bestandName(String tabelle) {
    const namen = {
      'Tasks': 'Aufgaben',
      'Notes': 'Notizen',
      'NoteFolders': 'Notizordner',
      'JournalEntries': 'Journaleinträge',
      'TimeEntry': 'Zeiteinträge',
      'planner_entries': 'Termine',
      'planner_entry_types': 'Termin-Typen',
      'planner_recurrences': 'Wiederholungen',
      'dashboard_layouts': 'Dashboard-Anordnungen',
      'ai_providers': 'KI-Anbieter',
      'user_ai_settings': 'KI-Einstellungen',
      'journal_reminders': 'Journal-Erinnerungen',
    };
    return namen[tabelle] ?? tabelle;
  }

  String _initialen(AdminBenutzer b) {
    final v = b.vorname.isNotEmpty ? b.vorname[0] : '';
    final n = b.nachname.isNotEmpty ? b.nachname[0] : '';
    final zusammen = '$v$n'.trim();
    return zusammen.isEmpty ? b.username.characters.first.toUpperCase()
                            : zusammen.toUpperCase();
  }

  String _zuletzt(AdminBenutzer b) {
    if (b.online) {
      return b.verbindungen > 1
          ? 'online (${b.verbindungen} Geräte)'
          : 'online';
    }
    final z = b.zuletztGesehen;
    if (z == null) return 'noch nie da gewesen';
    final her = DateTime.now().difference(z);
    if (her.inMinutes < 2) return 'gerade eben';
    if (her.inMinutes < 60) return 'vor ${her.inMinutes} Minuten';
    if (her.inHours < 24) return 'vor ${her.inHours} Stunden';
    if (her.inDays == 1) return 'gestern';
    return 'vor ${her.inDays} Tagen';
  }

  Future<void> _rollenZuweisen(AdminBenutzer b) async {
    final gewaehlt = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (_) => UserRolesSheet(benutzer: b, rollen: _rollen),
    );
    if (gewaehlt == null) return;
    try {
      await AdminService.rollenSetzen(b.id, gewaehlt);
      await _laden();
      _melde('Rollen von ${b.anzeigename} gespeichert');
    } on DioException catch (e) {
      _melde(_fehlertext(e));
    }
  }

  // ── Rollen ─────────────────────────────────────────────────────────────

  Widget _rollenListe() {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Ein Häkchen bei „Standard" entscheidet, was ein neu '
                'angelegter Nutzer bekommt.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            ..._rollen.map((r) => _rollenKachel(r, scheme)),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _rolleBearbeiten(null),
            icon: const Icon(Icons.add),
            label: const Text('Rolle'),
          ),
        ),
      ],
    );
  }

  Widget _rollenKachel(Rolle r, ColorScheme scheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Row(
          children: [
            Flexible(child: Text(r.name)),
            if (r.istStandard) ...[
              const SizedBox(width: 8),
              Chip(
                label: const Text('Standard', style: TextStyle(fontSize: 10)),
                backgroundColor: scheme.primaryContainer,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
            if (r.istSystem) ...[
              const SizedBox(width: 6),
              Icon(Icons.lock_outline, size: 14, color: scheme.outline),
            ],
          ],
        ),
        subtitle: Text(
          '${r.darfAlles ? "Alle Rechte" : "${r.rechte.length} Rechte"} · '
          '${r.nutzerAnzahl} ${r.nutzerAnzahl == 1 ? "Nutzer" : "Nutzer"}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (wahl) => _rollenAktion(wahl, r),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'bearbeiten', child: Text('Bearbeiten')),
            if (!r.istStandard)
              const PopupMenuItem(
                value: 'standard',
                child: Text('Als Standard für neue Nutzer'),
              ),
            if (r.istStandard)
              const PopupMenuItem(
                value: 'kein_standard',
                child: Text('Kein Standard mehr'),
              ),
            if (!r.istSystem && !r.istStandard)
              const PopupMenuItem(value: 'loeschen', child: Text('Löschen')),
          ],
        ),
        onTap: () => _rolleBearbeiten(r),
      ),
    );
  }

  Future<void> _rollenAktion(String wahl, Rolle r) async {
    try {
      switch (wahl) {
        case 'bearbeiten':
          await _rolleBearbeiten(r);
          return;
        case 'standard':
          await AdminService.standardrolleSetzen(r.id);
          _melde('Neue Nutzer bekommen jetzt „${r.name}"');
        case 'kein_standard':
          await AdminService.standardrolleSetzen(null);
          _melde('Neue Nutzer bekommen keine Rolle mehr und müssen '
              'freigeschaltet werden');
        case 'loeschen':
          if (!await _loeschenBestaetigen(r)) return;
          await AdminService.rolleLoeschen(r.id);
          _melde('„${r.name}" gelöscht');
      }
      await _laden();
    } on DioException catch (e) {
      _melde(_fehlertext(e));
    }
  }

  Future<bool> _loeschenBestaetigen(Rolle r) async {
    final betroffen = r.nutzerAnzahl;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('„${r.name}" löschen?'),
        content: Text(
          betroffen == 0
              ? 'Die Rolle hat gerade niemand.'
              : '$betroffen ${betroffen == 1 ? "Nutzer verliert" : "Nutzer verlieren"} '
                'damit die Rechte aus dieser Rolle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _rolleBearbeiten(Rolle? rolle) async {
    final geaendert = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (_) => RoleEditor(rolle: rolle, katalog: _katalog),
    );
    if (geaendert == true) await _laden();
  }
}

/// Punkt am Avatar: grün wenn verbunden, grau wenn nicht.
class _OnlinePunkt extends StatelessWidget {
  final bool online;
  final int verbindungen;
  final String initialen;

  const _OnlinePunkt({
    required this.online,
    required this.verbindungen,
    required this.initialen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: scheme.secondaryContainer,
            child: Text(initialen,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSecondaryContainer)),
          ),
          Positioned(
            right: 0,
            bottom: 2,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: online ? const Color(0xFF34C759) : scheme.outlineVariant,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hinweis extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Hinweis({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: scheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:productivity/provider/planner_provider.dart';
import 'package:productivity/tabs/planner/views/week_view.dart';
import 'package:productivity/tabs/planner/views/month_view.dart';
import 'package:productivity/tabs/planner/views/day_view.dart';
import 'package:productivity/tabs/planner/widgets/planner_edit_dialog.dart';
import 'package:productivity/tabs/planner/widgets/kalender_filter_dialog.dart';
import 'package:productivity/tabs/planner/widgets/planner_import_dialog.dart';
import 'package:productivity/widgets/drawer.dart';

/// Welchen Termin der Kalender beim Öffnen zeigen soll.
///
/// Kommt als Route-Argument, wenn jemand eine Mitteilung angetippt hat.
class PlannerZiel {
  final int entryId;

  const PlannerZiel({required this.entryId});
}

class PlannerTab extends StatefulWidget {
  const PlannerTab({super.key});

  @override
  State<PlannerTab> createState() => _PlannerTabState();
}

class _PlannerTabState extends State<PlannerTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _selectedDate;

  /// Der Termin aus der angetippten Mitteilung, solange er hervorgehoben
  /// wird. Wird beim ersten Antippen im Kalender wieder vergessen — die
  /// Hervorhebung soll den Blick lenken, nicht dauerhaft bleiben.
  int? _hervorgehoben;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedDate = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<PlannerProvider>();
      await provider.loadEntries();
      if (!mounted) return;
      provider.loadTypes();
      provider.loadKalender(alle: true);
      _zielAnsteuern();
    });
  }

  /// Springt auf die Woche des gemeinten Termins.
  ///
  /// Erst NACH dem Laden: vorher kennt der Provider den Termin nicht und
  /// wir wüssten nicht, auf welchen Tag zu springen ist. Findet sich der
  /// Termin nicht (gelöscht, oder ein anderes Konto), bleibt der Kalender
  /// einfach auf heute stehen — eine Fehlermeldung hülfe niemandem.
  void _zielAnsteuern() {
    final ziel = ModalRoute.of(context)?.settings.arguments;
    if (ziel is! PlannerZiel) return;

    final termin = context
        .read<PlannerProvider>()
        .entries
        .where((e) => e.id == ziel.entryId)
        .firstOrNull;
    if (termin == null) return;

    setState(() {
      _selectedDate = termin.scheduledAt;
      _hervorgehoben = termin.id;
    });
    // Die Wochenansicht ist der Standard, aber nicht garantiert — wer aus
    // einer Mitteilung kommt, soll den Termin im Raster sehen.
    _tabController.animateTo(0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const DrawerWidget(),
      appBar: AppBar(
        title: const Text('Kalender'),
        elevation: 0,
        actions: [
          // Der Knopf faerbt sich, sobald gefiltert wird — sonst sucht man
          // spaeter einen Termin, der nur ausgeblendet ist.
          IconButton(
            tooltip: 'Kalender anzeigen',
            isSelected: context.watch<PlannerProvider>().filterAktiv,
            icon: const Icon(Icons.filter_alt_outlined),
            selectedIcon: const Icon(Icons.filter_alt),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const KalenderFilterDialog(),
            ),
          ),
          IconButton(
            tooltip: 'Kalender importieren',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const PlannerImportDialog(),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Woche'),
            Tab(text: 'Monat'),
            Tab(text: 'Tag'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          WeekView(
            selectedDate: _selectedDate,
            hervorgehoben: _hervorgehoben,
            beiAuswahl: () => setState(() => _hervorgehoben = null),
          ),
          MonthView(selectedDate: _selectedDate),
          DayView(selectedDate: _selectedDate),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => PlannerEditDialog(
        onSubmit: (result, scope) {
          final provider = context.read<PlannerProvider>();
          if (result.recurrence != null) {
            provider.createRecurringEntry(
              title: result.title,
              description: result.description,
              typeId: result.typeId,
              scheduledAt: result.scheduledAt,
              endsAt: result.endsAt,
              notifyMinBefore: result.notifyMinBefore,
              color: result.color,
              recurrence: result.recurrence!.toJson(),
            );
          } else {
            provider.createEntry(
              title: result.title,
              description: result.description,
              typeId: result.typeId,
              scheduledAt: result.scheduledAt,
              endsAt: result.endsAt,
              notifyMinBefore: result.notifyMinBefore,
              color: result.color,
              participantIds: result.participantIds,
              calendarId: result.calendarId,
            );
          }
        },
      ),
    );
  }
}

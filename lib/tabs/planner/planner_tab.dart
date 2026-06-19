import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:productivity/provider/planner_provider.dart';
import 'package:productivity/tabs/planner/views/week_view.dart';
import 'package:productivity/tabs/planner/views/month_view.dart';
import 'package:productivity/tabs/planner/views/day_view.dart';
import 'package:productivity/tabs/planner/widgets/planner_edit_dialog.dart';
import 'package:productivity/widgets/drawer.dart';

class PlannerTab extends StatefulWidget {
  const PlannerTab({super.key});

  @override
  State<PlannerTab> createState() => _PlannerTabState();
}

class _PlannerTabState extends State<PlannerTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedDate = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlannerProvider>().loadEntries();
      context.read<PlannerProvider>().loadTypes();
    });
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
        title: const Text('Planner'),
        elevation: 0,
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
          WeekView(selectedDate: _selectedDate),
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
            );
          }
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:productivity/provider/planner_provider.dart';
import 'package:productivity/tabs/planner/widgets/planner_entry_card.dart';

class DayView extends StatefulWidget {
  final DateTime selectedDate;

  const DayView({Key? key, required this.selectedDate}) : super(key: key);

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.selectedDate;
  }

  String _getDayName(int weekday) {
    const days = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'];
    return days[weekday - 1];
  }

  String _getRelativeDay(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    final targetDay = DateTime(date.year, date.month, date.day);

    if (targetDay == today) return 'Heute';
    if (targetDay == yesterday) return 'Gestern';
    if (targetDay == tomorrow) return 'Morgen';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlannerProvider>(
      builder: (context, plannerProvider, child) {
        if (plannerProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final entries = plannerProvider.getEntriesForDay(_selectedDay);
        final relative = _getRelativeDay(_selectedDay);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => setState(() {
                          _selectedDay = _selectedDay.subtract(const Duration(days: 1));
                        }),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Column(
                        children: [
                          Text(
                            '${_getDayName(_selectedDay.weekday)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${_selectedDay.day}.${_selectedDay.month}.${_selectedDay.year}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          if (relative.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Chip(
                                label: Text(relative),
                                backgroundColor: Colors.blue[100],
                                labelStyle: TextStyle(color: Colors.blue[900]),
                              ),
                            ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => setState(() {
                          _selectedDay = _selectedDay.add(const Duration(days: 1));
                        }),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (entries.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${entries.length} Einträge',
                        style: TextStyle(
                          color: Colors.orange[900],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Keine Einträge an diesem Tag',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        return PlannerEntryCard(entry: entries[index]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

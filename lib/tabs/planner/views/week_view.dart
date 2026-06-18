import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:productivity/provider/planner_provider.dart';
import 'package:productivity/tabs/planner/widgets/planner_entry_card.dart';

class WeekView extends StatefulWidget {
  final DateTime selectedDate;

  const WeekView({Key? key, required this.selectedDate}) : super(key: key);

  @override
  State<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<WeekView> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = _getWeekStart(widget.selectedDate);
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlannerProvider>(
      builder: (context, plannerProvider, child) {
        if (plannerProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final entries = plannerProvider.getEntriesForWeek(_weekStart);
        final daysOfWeek = List.generate(7, (i) => _weekStart.add(Duration(days: i)));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => setState(() {
                      _weekStart = _weekStart.subtract(const Duration(days: 7));
                    }),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    '${_weekStart.day}.${_weekStart.month}. - ${_weekStart.add(const Duration(days: 6)).day}.${_weekStart.add(const Duration(days: 6)).month}.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      _weekStart = _weekStart.add(const Duration(days: 7));
                    }),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 7,
                itemBuilder: (context, index) {
                  final day = daysOfWeek[index];
                  final dayEntries = entries
                      .where((e) =>
                          e.scheduledAt.year == day.year &&
                          e.scheduledAt.month == day.month &&
                          e.scheduledAt.day == day.day)
                      .length;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () {
                        // Könnte hier zu DayView wechseln
                      },
                      child: Card(
                        child: Container(
                          width: 80,
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'][index],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                day.day.toString(),
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$dayEntries Einträge',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        'Keine Einträge diese Woche',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
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

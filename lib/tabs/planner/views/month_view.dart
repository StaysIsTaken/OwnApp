import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:productivity/provider/planner_provider.dart';

class MonthView extends StatefulWidget {
  final DateTime selectedDate;

  const MonthView({Key? key, required this.selectedDate}) : super(key: key);

  @override
  State<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<MonthView> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month);
  }

  int _daysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  int _firstWeekday(DateTime date) {
    return DateTime(date.year, date.month, 1).weekday;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlannerProvider>(
      builder: (context, plannerProvider, child) {
        final entries = plannerProvider.getEntriesForMonth(_currentMonth);
        final daysInMonth = _daysInMonth(_currentMonth);
        final firstWeekday = _firstWeekday(_currentMonth);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => setState(() {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                    }),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    _getMonthName(_currentMonth.month) + ' ${_currentMonth.year}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                    }),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: 42,
                itemBuilder: (context, index) {
                  final dayNumber = index - firstWeekday + 2;

                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    return Container();
                  }

                  final date = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
                  final dayEntries = entries
                      .where((e) =>
                          e.scheduledAt.year == date.year &&
                          e.scheduledAt.month == date.month &&
                          e.scheduledAt.day == date.day)
                      .toList();

                  final isToday = date.year == DateTime.now().year &&
                      date.month == DateTime.now().month &&
                      date.day == DateTime.now().day;

                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isToday ? Colors.blue : Colors.grey[300]!,
                        width: isToday ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Text(
                            dayNumber.toString(),
                            style: TextStyle(
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday ? Colors.blue : Colors.black,
                            ),
                          ),
                        ),
                        if (dayEntries.isNotEmpty)
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${dayEntries.length}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Gesamt: ${entries.length} Einträge',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
    ];
    return months[month - 1];
  }
}

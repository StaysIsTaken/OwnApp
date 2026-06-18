import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/provider/planner_provider.dart';
import 'package:productivity/tabs/planner/widgets/planner_edit_dialog.dart';

class MonthView extends StatefulWidget {
  final DateTime selectedDate;

  const MonthView({super.key, required this.selectedDate});

  @override
  State<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<MonthView> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
    );
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
        if (plannerProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

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
                      _currentMonth = DateTime(
                        _currentMonth.year,
                        _currentMonth.month - 1,
                      );
                    }),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      _currentMonth = DateTime(
                        _currentMonth.year,
                        _currentMonth.month + 1,
                      );
                    }),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            _buildWeekdayHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: _buildCalendarGrid(
                  context,
                  daysInMonth,
                  firstWeekday,
                  entries,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWeekdayHeader() {
    const labels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: labels
            .map(
              (l) => Expanded(
                child: Center(
                  child: Text(
                    l,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    int daysInMonth,
    int firstWeekday,
    List<PlannerEntry> entries,
  ) {
    final totalCells = ((daysInMonth + firstWeekday - 1) / 7).ceil() * 7;
    final weeks = totalCells ~/ 7;

    return Column(
      children: List.generate(weeks, (week) {
        return Expanded(
          child: Row(
            children: List.generate(7, (weekday) {
              final index = week * 7 + weekday;
              final dayNumber = index - firstWeekday + 2;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const Expanded(child: SizedBox());
              }
              final date = DateTime(
                _currentMonth.year,
                _currentMonth.month,
                dayNumber,
              );
              final dayEntries =
                  entries
                      .where(
                        (e) =>
                            e.scheduledAt.year == date.year &&
                            e.scheduledAt.month == date.month &&
                            e.scheduledAt.day == date.day,
                      )
                      .toList()
                    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
              return Expanded(
                child: _buildDayCell(context, date, dayNumber, dayEntries),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime date,
    int dayNumber,
    List<PlannerEntry> dayEntries,
  ) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    return DragTarget<PlannerEntry>(
      onAcceptWithDetails: (details) => _moveToDay(context, details.data, date),
      builder: (context, candidate, rejected) {
        final highlighted = candidate.isNotEmpty;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showCreateEntryDialog(context, date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: highlighted
                  ? theme.colorScheme.primary.withValues(alpha: 0.18)
                  : (isToday
                        ? theme.colorScheme.primary.withValues(alpha: 0.08)
                        : null),
              border: Border.all(
                color: highlighted
                    ? theme.colorScheme.primary
                    : (isToday ? Colors.blue : Colors.grey[800]!),
                width: (isToday || highlighted) ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: isToday
                        ? const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          )
                        : null,
                    child: Text(
                      dayNumber.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isToday ? Colors.white : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(child: _buildEntryList(context, dayEntries)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEntryList(BuildContext context, List<PlannerEntry> dayEntries) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const chipHeight = 18.0;
        final maxVisible = (constraints.maxHeight / chipHeight).floor().clamp(
          0,
          dayEntries.length,
        );
        final showCount = dayEntries.length > maxVisible && maxVisible > 0
            ? maxVisible - 1
            : maxVisible;
        final hiddenCount = dayEntries.length - showCount;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...dayEntries
                .take(showCount)
                .map((entry) => _buildEntryChip(context, entry)),
            if (hiddenCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  '+$hiddenCount mehr',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEntryChip(BuildContext context, PlannerEntry entry) {
    final chip = Container(
      height: 16,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: _getColorFromHex(entry.color),
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        '${_formatTime(entry.scheduledAt)} ${entry.title}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    return LongPressDraggable<PlannerEntry>(
      data: entry,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.9, child: SizedBox(width: 120, child: chip)),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: chip),
      child: GestureDetector(
        onTap: () => _showEditEntryDialog(context, entry),
        child: chip,
      ),
    );
  }

  void _moveToDay(BuildContext context, PlannerEntry entry, DateTime target) {
    if (entry.scheduledAt.year == target.year &&
        entry.scheduledAt.month == target.month &&
        entry.scheduledAt.day == target.day) {
      return; // same day, nothing to do
    }
    final newStart = DateTime(
      target.year,
      target.month,
      target.day,
      entry.scheduledAt.hour,
      entry.scheduledAt.minute,
    );
    final duration = entry.endsAt.difference(entry.scheduledAt);
    final newEnd = newStart.add(duration);
    context.read<PlannerProvider>().moveEntry(
      entry.id,
      scheduledAt: newStart,
      endsAt: newEnd,
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _getMonthName(int month) {
    const months = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];
    return months[month - 1];
  }

  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  void _showCreateEntryDialog(BuildContext context, DateTime date) {
    final scheduledAt = DateTime(date.year, date.month, date.day, 9, 0);
    showDialog(
      context: context,
      builder: (context) => PlannerEditDialog(
        initialScheduledAt: scheduledAt,
        initialEndsAt: scheduledAt.add(const Duration(hours: 1)),
        onSave:
            (
              title,
              description,
              typeId,
              start,
              end,
              notifyMinBefore,
              color,
              parentId,
              orderIndex,
            ) {
              context.read<PlannerProvider>().createEntry(
                title: title,
                description: description,
                typeId: typeId,
                scheduledAt: start,
                endsAt: end,
                notifyMinBefore: notifyMinBefore,
                color: color,
              );
            },
      ),
    );
  }

  void _showEditEntryDialog(BuildContext context, PlannerEntry entry) {
    final provider = context.read<PlannerProvider>();
    showDialog(
      context: context,
      builder: (context) => PlannerEditDialog(
        entry: entry,
        onDelete: () => provider.deleteEntry(entry.id),
        onSave:
            (
              title,
              description,
              typeId,
              start,
              end,
              notifyMinBefore,
              color,
              parentId,
              orderIndex,
            ) {
              provider.updateEntry(
                entry.id,
                title: title,
                description: description,
                typeId: typeId,
                scheduledAt: start,
                endsAt: end,
                notifyMinBefore: notifyMinBefore,
                color: color,
              );
            },
      ),
    );
  }
}

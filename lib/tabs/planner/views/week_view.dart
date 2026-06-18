import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/provider/planner_provider.dart';
import 'package:productivity/provider/settings_provider.dart';
import 'package:productivity/tabs/planner/widgets/planner_edit_dialog.dart';

class WeekView extends StatefulWidget {
  final DateTime selectedDate;

  const WeekView({Key? key, required this.selectedDate}) : super(key: key);

  @override
  State<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<WeekView> {
  static const double _hourHeight = 64.0;
  static const double _timeColumnWidth = 54.0;
  static const double _headerHeight = 64.0;

  late DateTime _weekStart;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _weekStart = _getWeekStart(widget.selectedDate);
    // Scroll to ~07:00 by default, like Teams/Google Calendar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          (7 * _hourHeight)
              .clamp(0.0, _scrollController.position.maxScrollExtent),
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlannerProvider, SettingsProvider>(
      builder: (context, plannerProvider, settingsProvider, child) {
        if (plannerProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final theme = Theme.of(context);
        final entries = plannerProvider.getEntriesForWeek(_weekStart);
        final daysOfWeek =
            List.generate(7, (i) => _weekStart.add(Duration(days: i)));
        final use24h = settingsProvider.use24hFormat;
        final weekEnd = _weekStart.add(const Duration(days: 6));
        final now = DateTime.now();

        return Column(
          children: [
            _buildNavHeader(theme, weekEnd, now),
            _buildDayHeaders(theme, daysOfWeek, now),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: SizedBox(
                  height: 24 * _hourHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTimeColumn(theme, use24h),
                      ...daysOfWeek.map((day) {
                        final dayEntries = entries
                            .where((e) => _isSameDay(e.scheduledAt, day))
                            .toList()
                          ..sort((a, b) =>
                              a.scheduledAt.compareTo(b.scheduledAt));
                        return Expanded(
                          child: _buildDayColumn(
                              context, theme, day, dayEntries, now),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNavHeader(ThemeData theme, DateTime weekEnd, DateTime now) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
            ),
            onPressed: () => setState(() {
              _weekStart = _weekStart.subtract(const Duration(days: 7));
            }),
            icon: const Icon(Icons.chevron_left),
          ),
          Column(
            children: [
              Text(
                '${_weekStart.day}. ${_monthShort(_weekStart.month)} – ${weekEnd.day}. ${_monthShort(weekEnd.month)}',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'KW ${_weekNumber(_weekStart)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor),
              ),
            ],
          ),
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
            ),
            onPressed: () => setState(() {
              _weekStart = _weekStart.add(const Duration(days: 7));
            }),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeaders(
      ThemeData theme, List<DateTime> daysOfWeek, DateTime now) {
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: _timeColumnWidth),
          ...daysOfWeek.map((day) {
            final dayIndex = day.weekday - 1;
            final dayName =
                ['MO', 'DI', 'MI', 'DO', 'FR', 'SA', 'SO'][dayIndex];
            final isToday = _isSameDay(day, now);
            final isWeekend = day.weekday >= 6;
            return Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dayName,
                      style: TextStyle(
                        color: isToday
                            ? theme.colorScheme.primary
                            : (isWeekend
                                ? theme.hintColor.withValues(alpha: 0.7)
                                : theme.hintColor),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isToday ? theme.colorScheme.primary : null,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        day.day.toString(),
                        style: TextStyle(
                          color: isToday
                              ? theme.colorScheme.onPrimary
                              : theme.textTheme.titleMedium?.color,
                          fontSize: 18,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimeColumn(ThemeData theme, bool use24h) {
    return SizedBox(
      width: _timeColumnWidth,
      child: Column(
        children: List.generate(24, (index) {
          return SizedBox(
            height: _hourHeight,
            child: index == 0
                ? null
                : Align(
                    alignment: Alignment.topRight,
                    child: Transform.translate(
                      offset: const Offset(0, -7),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          _formatHour(index, use24h),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.hintColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
          );
        }),
      ),
    );
  }

  Widget _buildDayColumn(BuildContext context, ThemeData theme, DateTime day,
      List<PlannerEntry> dayEntries, DateTime now) {
    final isToday = _isSameDay(day, now);
    final lineColor = theme.dividerColor.withValues(alpha: 0.25);

    return Container(
      decoration: BoxDecoration(
        color: isToday
            ? theme.colorScheme.primary.withValues(alpha: 0.04)
            : null,
        border: Border(left: BorderSide(color: lineColor)),
      ),
      child: Stack(
        children: [
          // Tappable hour cells with full-hour and half-hour guides
          Column(
            children: List.generate(24, (hour) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showCreateEntryDialog(
                    context, DateTime(day.year, day.month, day.day, hour, 0)),
                child: Container(
                  height: _hourHeight,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: lineColor),
                    ),
                  ),
                ),
              );
            }),
          ),
          // Entries
          ...dayEntries.map((entry) => _buildEntryCard(context, entry)),
          // "Now" indicator
          if (isToday) _buildNowIndicator(theme, now),
        ],
      ),
    );
  }

  Widget _buildEntryCard(BuildContext context, PlannerEntry entry) {
    final color = _getColorFromHex(entry.color);
    final start = entry.scheduledAt;
    final top = (start.hour + start.minute / 60.0) * _hourHeight;
    final height =
        ((entry.durationMin / 60.0) * _hourHeight).clamp(22.0, double.infinity);
    final end = start.add(Duration(minutes: entry.durationMin));
    final isCompact = height < 40;

    return Positioned(
      top: top + 1,
      left: 3,
      right: 3,
      height: height - 2,
      child: GestureDetector(
        onTap: () => _showEditEntryDialog(context, entry),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(7),
            border: Border(left: BorderSide(color: color, width: 3.5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style: TextStyle(
                  color: Color.lerp(color, Colors.white, 0.65),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
                maxLines: isCompact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!isCompact) ...[
                const SizedBox(height: 2),
                Text(
                  '${_formatClock(start)} – ${_formatClock(end)}',
                  style: TextStyle(
                    color: Color.lerp(color, Colors.white, 0.4),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNowIndicator(ThemeData theme, DateTime now) {
    final top = (now.hour + now.minute / 60.0) * _hourHeight;
    return Positioned(
      top: top - 4,
      left: 0,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: Color(0xFFE53935),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              color: const Color(0xFFE53935),
            ),
          ),
        ],
      ),
    );
  }

  String _formatHour(int hour, bool use24h) {
    if (use24h) {
      return '${hour.toString().padLeft(2, '0')}:00';
    }
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour < 12 ? 'AM' : 'PM';
    return '$h $period';
  }

  String _formatClock(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _monthShort(int month) {
    const m = [
      'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
      'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'
    ];
    return m[month - 1];
  }

  int _weekNumber(DateTime date) {
    final dayOfYear = int.parse(
        DateTime(date.year, date.month, date.day)
            .difference(DateTime(date.year, 1, 1))
            .inDays
            .toString());
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  void _showCreateEntryDialog(BuildContext context, DateTime scheduledAt) {
    showDialog(
      context: context,
      builder: (context) => PlannerEditDialog(
        initialScheduledAt: scheduledAt,
        initialDurationMin: 60,
        onSave: (title, description, type, time, durationMin, notifyMinBefore,
            color, parentId, orderIndex) {
          context.read<PlannerProvider>().createEntry(
                title: title,
                description: description,
                type: type,
                scheduledAt: time,
                durationMin: durationMin,
                notifyMinBefore: notifyMinBefore,
                color: color,
              );
        },
      ),
    );
  }

  void _showEditEntryDialog(BuildContext context, PlannerEntry entry) {
    showDialog(
      context: context,
      builder: (context) => PlannerEditDialog(
        entry: entry,
        onSave: (title, description, type, time, durationMin, notifyMinBefore,
            color, parentId, orderIndex) {
          context.read<PlannerProvider>().updateEntry(
                entry.id,
                title: title,
                description: description,
                type: type,
                scheduledAt: time,
                durationMin: durationMin,
                notifyMinBefore: notifyMinBefore,
                color: color,
              );
        },
      ),
    );
  }
}

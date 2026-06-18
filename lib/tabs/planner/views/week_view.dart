import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/provider/planner_provider.dart';
import 'package:productivity/provider/settings_provider.dart';
import 'package:productivity/tabs/planner/widgets/planner_edit_dialog.dart';

class WeekView extends StatefulWidget {
  final DateTime selectedDate;

  const WeekView({super.key, required this.selectedDate});

  @override
  State<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<WeekView> {
  static const double _hourHeight = 64.0;
  static const double _timeColumnWidth = 54.0;
  static const double _headerHeight = 64.0;
  static const int _snapMinutes = 15;

  late DateTime _weekStart;
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _dayKeys = List.generate(7, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    _weekStart = _getWeekStart(widget.selectedDate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          (7 * _hourHeight).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          ),
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
        final daysOfWeek = List.generate(
          7,
          (i) => _weekStart.add(Duration(days: i)),
        );
        final use24h = settingsProvider.use24hFormat;
        final weekEnd = _weekStart.add(const Duration(days: 6));
        final now = DateTime.now();

        return Column(
          children: [
            _buildNavHeader(theme, weekEnd),
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
                      ...List.generate(daysOfWeek.length, (index) {
                        final day = daysOfWeek[index];
                        final dayEntries =
                            entries
                                .where((e) => _isSameDay(e.scheduledAt, day))
                                .toList()
                              ..sort(
                                (a, b) =>
                                    a.scheduledAt.compareTo(b.scheduledAt),
                              );
                        return Expanded(
                          child: _buildDayColumn(
                            context,
                            theme,
                            day,
                            index,
                            dayEntries,
                            now,
                          ),
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

  Widget _buildNavHeader(ThemeData theme, DateTime weekEnd) {
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
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'KW ${_weekNumber(_weekStart)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
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
    ThemeData theme,
    List<DateTime> daysOfWeek,
    DateTime now,
  ) {
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
            final dayName = [
              'MO',
              'DI',
              'MI',
              'DO',
              'FR',
              'SA',
              'SO',
            ][dayIndex];
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
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.w500,
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

  Widget _buildDayColumn(
    BuildContext context,
    ThemeData theme,
    DateTime day,
    int dayIndex,
    List<PlannerEntry> dayEntries,
    DateTime now,
  ) {
    final isToday = _isSameDay(day, now);
    final lineColor = theme.dividerColor.withValues(alpha: 0.25);

    return DragTarget<PlannerEntry>(
      onAcceptWithDetails: (details) =>
          _handleDrop(context, day, dayIndex, details.data, details.offset),
      builder: (context, candidate, rejected) {
        return Container(
          key: _dayKeys[dayIndex],
          decoration: BoxDecoration(
            color: candidate.isNotEmpty
                ? theme.colorScheme.primary.withValues(alpha: 0.10)
                : (isToday
                      ? theme.colorScheme.primary.withValues(alpha: 0.04)
                      : null),
            border: Border(left: BorderSide(color: lineColor)),
          ),
          child: Stack(
            children: [
              Column(
                children: List.generate(24, (hour) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showCreateEntryDialog(
                      context,
                      DateTime(day.year, day.month, day.day, hour, 0),
                    ),
                    child: Container(
                      height: _hourHeight,
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: lineColor)),
                      ),
                    ),
                  );
                }),
              ),
              ...dayEntries.map(
                (entry) => _buildEntryCard(context, theme, entry),
              ),
              if (isToday) _buildNowIndicator(now),
            ],
          ),
        );
      },
    );
  }

  void _handleDrop(
    BuildContext context,
    DateTime day,
    int dayIndex,
    PlannerEntry entry,
    Offset globalOffset,
  ) {
    final box =
        _dayKeys[dayIndex].currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalOffset);
    var minutes = (local.dy / _hourHeight * 60).round();
    minutes = (minutes / _snapMinutes).round() * _snapMinutes;
    minutes = minutes.clamp(0, 24 * 60 - _snapMinutes);

    final newStart = DateTime(
      day.year,
      day.month,
      day.day,
    ).add(Duration(minutes: minutes));
    final duration = entry.endsAt.difference(entry.scheduledAt);
    final newEnd = newStart.add(duration);

    context.read<PlannerProvider>().moveEntry(
      entry.id,
      scheduledAt: newStart,
      endsAt: newEnd,
    );
  }

  Widget _buildEntryCard(
    BuildContext context,
    ThemeData theme,
    PlannerEntry entry,
  ) {
    final color = _getColorFromHex(entry.color);
    final start = entry.scheduledAt;
    final top = (start.hour + start.minute / 60.0) * _hourHeight;
    final durationMin = entry.endsAt.difference(start).inMinutes;
    final height = ((durationMin / 60.0) * _hourHeight).clamp(
      22.0,
      double.infinity,
    );
    final isCompact = height < 40;
    final colWidth = (MediaQuery.of(context).size.width - _timeColumnWidth) / 7;

    final cardContent = Container(
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
              '${_formatClock(start)} – ${_formatClock(entry.endsAt)}',
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
    );

    return Positioned(
      top: top + 1,
      left: 3,
      right: 3,
      height: height - 2,
      child: LongPressDraggable<PlannerEntry>(
        data: entry,
        dragAnchorStrategy: childDragAnchorStrategy,
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.9,
            child: SizedBox(
              width: colWidth - 6,
              height: height - 2,
              child: cardContent,
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: cardContent),
        child: GestureDetector(
          onTap: () => _showEditEntryDialog(context, entry),
          child: cardContent,
        ),
      ),
    );
  }

  Widget _buildNowIndicator(DateTime now) {
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
          Expanded(child: Container(height: 2, color: const Color(0xFFE53935))),
        ],
      ),
    );
  }

  String _formatHour(int hour, bool use24h) {
    if (use24h) return '${hour.toString().padLeft(2, '0')}:00';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour < 12 ? 'AM' : 'PM';
    return '$h $period';
  }

  String _formatClock(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _monthShort(int month) {
    const m = [
      'Jan',
      'Feb',
      'Mär',
      'Apr',
      'Mai',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Okt',
      'Nov',
      'Dez',
    ];
    return m[month - 1];
  }

  int _weekNumber(DateTime date) {
    final dayOfYear = DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime(date.year, 1, 1)).inDays;
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/time_entry.dart';

class TimeWidget extends StatefulWidget {
  final List<TimeEntry> timeEntries;
  final Duration timeTrackedToday;
  final Duration timeTrackedThisWeek;
  final TimeEntry? activeEntry;

  // Daily goal in hours (configurable in the future)
  static const int dailyGoalHours = 8;

  const TimeWidget({
    super.key,
    required this.timeEntries,
    required this.timeTrackedToday,
    required this.timeTrackedThisWeek,
    this.activeEntry,
  });

  @override
  State<TimeWidget> createState() => _TimeWidgetState();
}

class _TimeWidgetState extends State<TimeWidget> {
  Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    if (widget.activeEntry != null) {
      _liveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(covariant TimeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeEntry != widget.activeEntry) {
      _liveTimer?.cancel();
      if (widget.activeEntry != null) {
        _liveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final goalSeconds = TimeWidget.dailyGoalHours * 3600;
    final progress = (widget.timeTrackedToday.inSeconds / goalSeconds).clamp(0.0, 1.0);

    Duration activeDuration = Duration.zero;
    if (widget.activeEntry != null) {
      activeDuration = DateTime.now().difference(widget.activeEntry!.startTime);
    }

    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, AppRoutes.time),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule_outlined, color: colors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Zeit',
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: colors.outline),
                ],
              ),
              const SizedBox(height: 16),
              // Today's tracked time - hero number
              Center(
                child: Column(
                  children: [
                    Text(
                      _formatDuration(widget.timeTrackedToday),
                      style: text.displaySmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Heute',
                      style: text.labelMedium?.copyWith(color: colors.outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Progress bar to daily goal
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: colors.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation(
                    progress >= 1.0 ? colors.tertiary : colors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(progress * 100).toInt()}% von ${TimeWidget.dailyGoalHours}h',
                    style: text.labelSmall?.copyWith(color: colors.outline),
                  ),
                  Text(
                    'Diese Woche: ${_formatDuration(widget.timeTrackedThisWeek)}',
                    style: text.labelSmall?.copyWith(color: colors.outline),
                  ),
                ],
              ),
              if (widget.activeEntry != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.activeEntry!.description.isNotEmpty
                                  ? widget.activeEntry!.description
                                  : 'Aktiver Timer',
                              style: text.bodySmall?.copyWith(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Läuft seit ${_formatDuration(activeDuration)}',
                              style: text.labelSmall?.copyWith(
                                color: colors.onPrimaryContainer.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

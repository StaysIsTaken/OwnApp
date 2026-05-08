import 'package:flutter/material.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/task.dart';

class TasksWidget extends StatelessWidget {
  final List<Task> tasks;
  final List<Task> tasksDueToday;

  const TasksWidget({
    super.key,
    required this.tasks,
    required this.tasksDueToday,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final todoCount = tasks.where((t) => t.kanbanState == 'todo').length;
    final inProgressCount = tasks.where((t) => t.kanbanState == 'in_progress').length;
    final doneCount = tasks.where((t) => t.kanbanState == 'done').length;

    return _DashboardCard(
      onTap: () => Navigator.pushNamed(context, AppRoutes.tasks),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.task_outlined, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Tasks',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: colors.outline),
            ],
          ),
          const SizedBox(height: 16),
          // Stats
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  count: todoCount,
                  label: 'Zu tun',
                  bgColor: colors.errorContainer.withValues(alpha: 0.6),
                  textColor: colors.onErrorContainer,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  count: inProgressCount,
                  label: 'Aktiv',
                  bgColor: colors.secondaryContainer,
                  textColor: colors.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  count: doneCount,
                  label: 'Fertig',
                  bgColor: colors.tertiaryContainer,
                  textColor: colors.onTertiaryContainer,
                ),
              ),
            ],
          ),
          if (tasksDueToday.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.error.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_rounded, color: colors.error, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Heute fällig: ${tasksDueToday.length}',
                        style: text.labelLarge?.copyWith(
                          color: colors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...tasksDueToday.take(3).map((task) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 6, color: colors.error),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                task.title,
                                style: text.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )),
                  if (tasksDueToday.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+ ${tasksDueToday.length - 3} weitere',
                        style: text.labelSmall?.copyWith(color: colors.error),
                      ),
                    ),
                ],
              ),
            ),
          ] else if (tasks.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.tertiaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: colors.tertiary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Keine Tasks heute fällig',
                    style: text.bodySmall?.copyWith(
                      color: colors.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final int count;
  final String label;
  final Color bgColor;
  final Color textColor;

  const _MiniStat({
    required this.count,
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: text.titleLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: text.labelSmall?.copyWith(color: textColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _DashboardCard({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

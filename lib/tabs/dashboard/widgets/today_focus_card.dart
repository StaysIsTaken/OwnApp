import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/meal_plan.dart';
import 'package:productivity/dataclasses/recipe.dart';

class TodayFocusCard extends StatelessWidget {
  final int tasksDueToday;
  final Duration timeTrackedToday;
  final List<MealPlanEntry> todayMealPlan;
  final List<Recipe> recipes;
  final double estimatedShoppingCost;

  const TodayFocusCard({
    super.key,
    required this.tasksDueToday,
    required this.timeTrackedToday,
    required this.todayMealPlan,
    required this.recipes,
    required this.estimatedShoppingCost,
  });

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _getMealsSummary() {
    if (todayMealPlan.isEmpty) return 'Keine Mahlzeiten geplant';
    final recipeMap = {for (var r in recipes) r.id: r};
    final mealNames = todayMealPlan
        .map((e) => recipeMap[e.recipeId]?.name ?? 'Unbekannt')
        .toList();
    if (mealNames.length > 2) {
      return '${mealNames.take(2).join(", ")} +${mealNames.length - 2} weitere';
    }
    return mealNames.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today_rounded, color: colors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'Heute im Fokus',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRow(
            colors: colors,
            text: text,
            icon: Icons.task_alt_rounded,
            iconColor: tasksDueToday > 0 ? colors.error : colors.tertiary,
            label: 'Tasks fällig',
            value: tasksDueToday > 0
                ? '$tasksDueToday ${tasksDueToday == 1 ? "Task" : "Tasks"}'
                : 'Keine offen',
          ),
          const SizedBox(height: 12),
          _buildRow(
            colors: colors,
            text: text,
            icon: Icons.timer_outlined,
            iconColor: colors.secondary,
            label: 'Zeit getrackt',
            value: timeTrackedToday.inMinutes > 0
                ? _formatDuration(timeTrackedToday)
                : 'Noch nichts',
          ),
          const SizedBox(height: 12),
          _buildRow(
            colors: colors,
            text: text,
            icon: Icons.restaurant_rounded,
            iconColor: colors.tertiary,
            label: 'Mahlzeiten',
            value: _getMealsSummary(),
          ),
          if (estimatedShoppingCost > 0) ...[
            const SizedBox(height: 12),
            _buildRow(
              colors: colors,
              text: text,
              icon: Icons.euro_rounded,
              iconColor: colors.primary,
              label: 'Einkauf geplant',
              value: '~ €${estimatedShoppingCost.toStringAsFixed(2)}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow({
    required ColorScheme colors,
    required TextTheme text,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: text.bodyMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

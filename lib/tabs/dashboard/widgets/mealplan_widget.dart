import 'package:flutter/material.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/meal_plan.dart';
import 'package:productivity/dataclasses/recipe.dart';

class MealplanWidget extends StatelessWidget {
  final List<MealPlanEntry> mealPlanEntries;
  final List<Recipe> recipes;

  const MealplanWidget({
    super.key,
    required this.mealPlanEntries,
    required this.recipes,
  });

  List<MealPlanEntry> _getTodayMeals() {
    final today = DateTime.now();
    return mealPlanEntries
        .where((e) =>
            e.date.year == today.year &&
            e.date.month == today.month &&
            e.date.day == today.day)
        .toList();
  }

  Map<String, MealPlanEntry?> _organizeByMealType() {
    final today = _getTodayMeals();
    final result = <String, MealPlanEntry?>{
      'breakfast': null,
      'lunch': null,
      'dinner': null,
    };
    for (final entry in today) {
      final type = entry.mealType?.toLowerCase() ?? 'lunch';
      if (result.containsKey(type)) {
        result[type] = entry;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final recipeMap = {for (var r in recipes) r.id: r};
    final mealsByType = _organizeByMealType();
    final todayMeals = _getTodayMeals();

    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, AppRoutes.mealPlan),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.restaurant_rounded, color: colors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Heute essen',
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: colors.outline),
                ],
              ),
              const SizedBox(height: 12),
              if (todayMeals.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          color: colors.outline, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Kein Plan für heute',
                          style: text.bodySmall?.copyWith(color: colors.outline),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                _buildMealRow(
                  colors: colors,
                  text: text,
                  emoji: '🌅',
                  label: 'Frühstück',
                  meal: mealsByType['breakfast'],
                  recipeMap: recipeMap,
                ),
                const SizedBox(height: 8),
                _buildMealRow(
                  colors: colors,
                  text: text,
                  emoji: '☀️',
                  label: 'Mittag',
                  meal: mealsByType['lunch'],
                  recipeMap: recipeMap,
                ),
                const SizedBox(height: 8),
                _buildMealRow(
                  colors: colors,
                  text: text,
                  emoji: '🌙',
                  label: 'Abend',
                  meal: mealsByType['dinner'],
                  recipeMap: recipeMap,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealRow({
    required ColorScheme colors,
    required TextTheme text,
    required String emoji,
    required String label,
    required MealPlanEntry? meal,
    required Map<String, Recipe> recipeMap,
  }) {
    final recipe = meal != null ? recipeMap[meal.recipeId] : null;
    final hasMeal = recipe != null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: hasMeal
            ? colors.primaryContainer.withValues(alpha: 0.3)
            : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: text.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              hasMeal ? recipe.name : 'Nicht geplant',
              style: text.bodySmall?.copyWith(
                color: hasMeal ? colors.onSurface : colors.outline,
                fontStyle: hasMeal ? FontStyle.normal : FontStyle.italic,
                fontWeight: hasMeal ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasMeal && meal!.servings > 0)
            Text(
              '${meal.servings}P',
              style: text.labelSmall?.copyWith(color: colors.outline),
            ),
        ],
      ),
    );
  }
}

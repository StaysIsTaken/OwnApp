import 'package:flutter/material.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/pantry_item.dart';
import 'package:productivity/dataclasses/ingredient.dart';

class PantryWidget extends StatelessWidget {
  final List<PantryItem> pantryItems;
  final Map<String, Ingredient> ingredientMap;
  final List<PantryItem> lowItems;
  final List<PantryItem> expiringItems;

  const PantryWidget({
    super.key,
    required this.pantryItems,
    required this.ingredientMap,
    required this.lowItems,
    required this.expiringItems,
  });

  String _formatExpiry(DateTime expiry) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);
    final days = expiryDay.difference(today).inDays;

    if (days == 0) return 'Heute';
    if (days == 1) return 'Morgen';
    if (days < 0) return 'Abgelaufen';
    return 'In $days Tagen';
  }

  Color _getExpiryColor(DateTime expiry, ColorScheme colors) {
    final days = expiry.difference(DateTime.now()).inDays;
    if (days <= 1) return colors.error;
    if (days <= 3) return Colors.orange;
    return colors.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, AppRoutes.pantry),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.kitchen_outlined, color: colors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Vorräte',
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: colors.outline),
                ],
              ),
              const SizedBox(height: 16),
              if (lowItems.isEmpty && expiringItems.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: colors.tertiary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Alle Vorräte ausreichend',
                          style: text.bodySmall?.copyWith(
                            color: colors.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (lowItems.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: colors.error, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Niedriger Bestand: ${lowItems.length}',
                      style: text.labelLarge?.copyWith(
                        color: colors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...lowItems.take(3).map((item) {
                  final ing = ingredientMap[item.ingredientId];
                  final isCritical = item.amount < item.minAmount / 2;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isCritical ? colors.error : Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ing?.name ?? 'Unbekannt',
                            style: text.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${item.amount.toStringAsFixed(1)}/${item.minAmount.toStringAsFixed(1)}',
                          style: text.labelSmall?.copyWith(color: colors.outline),
                        ),
                      ],
                    ),
                  );
                }),
                if (lowItems.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+ ${lowItems.length - 3} weitere',
                      style: text.labelSmall?.copyWith(color: colors.outline),
                    ),
                  ),
              ],
              if (expiringItems.isNotEmpty) ...[
                if (lowItems.isNotEmpty) const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.event_busy_rounded, color: Colors.orange, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Bald ablaufend: ${expiringItems.length}',
                      style: text.labelLarge?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...expiringItems.take(2).map((item) {
                  final ing = ingredientMap[item.ingredientId];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: _getExpiryColor(item.expiryDate!, colors),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ing?.name ?? 'Unbekannt',
                            style: text.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatExpiry(item.expiryDate!),
                          style: text.labelSmall?.copyWith(
                            color: _getExpiryColor(item.expiryDate!, colors),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (expiringItems.length > 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+ ${expiringItems.length - 2} weitere',
                      style: text.labelSmall?.copyWith(color: colors.outline),
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

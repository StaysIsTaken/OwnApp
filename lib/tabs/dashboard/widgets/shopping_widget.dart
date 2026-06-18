import 'package:flutter/material.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/pantry_extras.dart';
import 'package:productivity/dataclasses/ingredient.dart';
import 'package:productivity/dataclasses/shop.dart';
import 'package:productivity/dataclasses/shopping_list_item_price.dart';

class ShoppingWidget extends StatelessWidget {
  final List<ShoppingListItem> shoppingItems;
  final Map<String, Ingredient> ingredientMap;
  final Map<String, List<ShoppingListItemPrice>> pricesByItemId;
  final List<Shop> shops;
  final double estimatedCost;
  final Future<void> Function(ShoppingListItem) onItemBought;

  const ShoppingWidget({
    super.key,
    required this.shoppingItems,
    required this.ingredientMap,
    required this.pricesByItemId,
    required this.shops,
    required this.estimatedCost,
    required this.onItemBought,
  });

  String? _getBestShop() {
    final shopMap = {for (var s in shops) s.id: s};
    final shopTotals = <String, double>{};

    for (final item in shoppingItems.where((i) => !i.isBought)) {
      final prices = pricesByItemId[item.id];
      if (prices == null || prices.isEmpty) continue;

      for (final price in prices) {
        shopTotals[price.shopId] =
            (shopTotals[price.shopId] ?? 0) + (price.price * item.amount);
      }
    }

    if (shopTotals.isEmpty) return null;
    final bestShopId = shopTotals.entries
        .reduce((a, b) => a.value < b.value ? a : b)
        .key;
    return shopMap[bestShopId]?.name;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final openItems = shoppingItems.where((i) => !i.isBought).toList();
    final bestShop = _getBestShop();

    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, AppRoutes.shoppingList),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    color: colors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Einkauf',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: colors.outline),
                ],
              ),
              const SizedBox(height: 12),
              if (openItems.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: colors.tertiary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Einkaufsliste leer',
                          style: text.bodySmall?.copyWith(
                            color: colors.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  '${openItems.length} ${openItems.length == 1 ? "Item" : "Items"} offen',
                  style: text.bodySmall?.copyWith(color: colors.outline),
                ),
                const SizedBox(height: 12),
                ...openItems.take(4).map((item) {
                  final ing = ingredientMap[item.ingredientId];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: false,
                            onChanged: (_) => onItemBought(item),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
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
                          item.amount.toStringAsFixed(
                            item.amount == item.amount.toInt() ? 0 : 1,
                          ),
                          style: text.labelSmall?.copyWith(
                            color: colors.outline,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (openItems.length > 4)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 32),
                    child: Text(
                      '+ ${openItems.length - 4} weitere',
                      style: text.labelSmall?.copyWith(color: colors.outline),
                    ),
                  ),
                if (estimatedCost > 0 || bestShop != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        if (estimatedCost > 0)
                          Row(
                            children: [
                              Icon(
                                Icons.euro_rounded,
                                size: 14,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Geschätzt',
                                  style: text.labelSmall?.copyWith(
                                    color: colors.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              Text(
                                '~ €${estimatedCost.toStringAsFixed(2)}',
                                style: text.labelMedium?.copyWith(
                                  color: colors.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        if (bestShop != null) ...[
                          if (estimatedCost > 0) const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.storefront_outlined,
                                size: 14,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Bester Shop',
                                  style: text.labelSmall?.copyWith(
                                    color: colors.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              Text(
                                bestShop,
                                style: text.labelMedium?.copyWith(
                                  color: colors.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

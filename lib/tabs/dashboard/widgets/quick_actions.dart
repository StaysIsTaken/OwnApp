import 'package:flutter/material.dart';
import 'package:productivity/main.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // On mobile (< 400px) use 2x2 grid, otherwise 4 in a row
        final isCompact = constraints.maxWidth < 400;

        final actions = [
          _QuickActionButton(
            icon: Icons.task_outlined,
            label: 'Tasks',
            colors: colors,
            text: text,
            onTap: () => Navigator.pushNamed(context, AppRoutes.tasks),
            backgroundColor: colors.primaryContainer,
            iconColor: colors.onPrimaryContainer,
          ),
          _QuickActionButton(
            icon: Icons.schedule_outlined,
            label: 'Zeit',
            colors: colors,
            text: text,
            onTap: () => Navigator.pushNamed(context, AppRoutes.time),
            backgroundColor: colors.secondaryContainer,
            iconColor: colors.onSecondaryContainer,
          ),
          _QuickActionButton(
            icon: Icons.shopping_cart_outlined,
            label: 'Einkauf',
            colors: colors,
            text: text,
            onTap: () => Navigator.pushNamed(context, AppRoutes.shoppingList),
            backgroundColor: colors.tertiaryContainer,
            iconColor: colors.onTertiaryContainer,
          ),
          _QuickActionButton(
            icon: Icons.kitchen_outlined,
            label: 'Vorrat',
            colors: colors,
            text: text,
            onTap: () => Navigator.pushNamed(context, AppRoutes.pantry),
            backgroundColor: colors.surfaceContainerHighest,
            iconColor: colors.primary,
          ),
        ];

        if (isCompact) {
          // 2x2 Grid
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: actions[0]),
                  const SizedBox(width: 12),
                  Expanded(child: actions[1]),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: actions[2]),
                  const SizedBox(width: 12),
                  Expanded(child: actions[3]),
                ],
              ),
            ],
          );
        } else {
          // Row
          return Row(
            children: [
              for (int i = 0; i < actions.length; i++) ...[
                Expanded(child: actions[i]),
                if (i < actions.length - 1) const SizedBox(width: 12),
              ],
            ],
          );
        }
      },
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colors;
  final TextTheme text;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconColor;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.colors,
    required this.text,
    required this.onTap,
    required this.backgroundColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 28, color: iconColor),
              const SizedBox(height: 8),
              Text(
                label,
                style: text.labelMedium?.copyWith(
                  color: iconColor,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

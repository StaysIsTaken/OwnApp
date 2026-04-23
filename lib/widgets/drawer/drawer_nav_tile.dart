import 'package:flutter/material.dart';
import 'drawer_models.dart';

class DrawerNavTile extends StatelessWidget {
  final NavItem item;
  final bool isActive;
  final ColorScheme scheme;
  final bool isDark;
  final VoidCallback onTap;

  const DrawerNavTile({
    super.key,
    required this.item,
    required this.isActive,
    required this.scheme,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = scheme.primary;
    final activeBg = scheme.primary.withOpacity(0.12);
    final inactiveBg = Colors.transparent;
    final textColor = isActive
        ? activeColor
        : (isDark ? Colors.white70 : Colors.black87);
    final iconColor = isActive
        ? activeColor
        : (isDark ? Colors.white54 : Colors.black45);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isActive ? activeBg : inactiveBg,
        borderRadius: BorderRadius.circular(AppDrawerStyles.tileBorderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDrawerStyles.tileBorderRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isActive ? item.iconActive : item.icon,
                  color: iconColor,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14.5,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (item.badge != null) _Badge(label: item.badge!),
                if (isActive)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: activeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class DrawerSectionLabel extends StatelessWidget {
  final String label;
  const DrawerSectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 14, bottom: 2, top: 8),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white38 : Colors.black38,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

// Shared style constants used across drawer widgets
class AppDrawerStyles {
  AppDrawerStyles._();
  static const double tileBorderRadius = 12.0;
}

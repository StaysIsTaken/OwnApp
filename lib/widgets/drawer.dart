import 'package:flutter/material.dart';
import 'package:productivity/main.dart';
import 'drawer/drawer_header.dart';
import 'drawer/drawer_footer.dart';
import 'drawer/drawer_nav_tile.dart';
import 'drawer/drawer_models.dart';

class DrawerWidget extends StatefulWidget {
  const DrawerWidget({super.key});

  @override
  State<DrawerWidget> createState() => _DrawerWidgetState();
}

class _DrawerWidgetState extends State<DrawerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  // Split items into categories
  static const _mainItems = [
    NavItem(
      icon: Icons.home_outlined,
      iconActive: Icons.home_rounded,
      label: 'Home',
      route: AppRoutes.home,
    ),
    NavItem(
      icon: Icons.menu_book_outlined,
      iconActive: Icons.menu_book_rounded,
      label: 'Rezepte',
      route: AppRoutes.recipes,
    ),
    NavItem(
      icon: Icons.schedule_outlined,
      iconActive: Icons.schedule_rounded,
      label: 'Zeiten',
      route: AppRoutes.time,
    ),
    NavItem(
      icon: Icons.chat_outlined,
      iconActive: Icons.chat_rounded,
      label: 'Chat',
      route: AppRoutes.chat,
    ),
  ];

  static const _pantryItems = [
    NavItem(
      icon: Icons.inventory_2_outlined,
      iconActive: Icons.inventory_2_rounded,
      label: 'Vorräte',
      route: AppRoutes.pantry,
    ),
    NavItem(
      icon: Icons.shopping_cart_outlined,
      iconActive: Icons.shopping_cart_rounded,
      label: 'Einkaufsliste',
      route: AppRoutes.shoppingList,
    ),
    NavItem(
      icon: Icons.calendar_month_outlined,
      iconActive: Icons.calendar_month_rounded,
      label: 'Essensplaner',
      route: AppRoutes.mealPlan,
    ),
  ];

  static const _managementItems = [
    NavItem(
      icon: Icons.category_outlined,
      iconActive: Icons.category_rounded,
      label: 'Kategorien',
      route: AppRoutes.categories,
    ),
    NavItem(
      icon: Icons.eco_outlined,
      iconActive: Icons.eco_rounded,
      label: 'Zutaten',
      route: AppRoutes.ingredients,
    ),
    NavItem(
      icon: Icons.straighten_outlined,
      iconActive: Icons.straighten_rounded,
      label: 'Einheiten',
      route: AppRoutes.units,
    ),
    NavItem(
      icon: Icons.warehouse_outlined,
      iconActive: Icons.warehouse_rounded,
      label: 'Lagerorte',
      route: AppRoutes.storageLocations,
    ),
  ];

  static const _settingsItem = NavItem(
    icon: Icons.settings_outlined,
    iconActive: Icons.settings_rounded,
    label: 'Einstellungen',
    route: AppRoutes.settings,
  );

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _currentRoute(BuildContext context) =>
      ModalRoute.of(context)?.settings.name ?? '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentRoute = _currentRoute(context);

    return Drawer(
      width: 285,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            DrawerHeaderWidget(scheme: scheme, isDark: isDark),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                children: [
                  const DrawerSectionLabel(label: 'NAVIGATION'),
                  const SizedBox(height: 4),
                  ..._mainItems.map((item) => _buildTile(item, currentRoute, scheme, isDark)),
                  
                  const SizedBox(height: 24),
                  const DrawerSectionLabel(label: 'VORRÄTE'),
                  const SizedBox(height: 4),
                  ..._pantryItems.map((item) => _buildTile(item, currentRoute, scheme, isDark)),

                  const SizedBox(height: 24),
                  const DrawerSectionLabel(label: 'VERWALTUNG'),
                  const SizedBox(height: 4),
                  ..._managementItems.map((item) => _buildTile(item, currentRoute, scheme, isDark)),
                ],
              ),
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _buildTile(_settingsItem, currentRoute, scheme, isDark),
            ),
            DrawerFooterWidget(scheme: scheme, isDark: isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(NavItem item, String currentRoute, ColorScheme scheme, bool isDark) {
    return DrawerNavTile(
      item: item,
      isActive: currentRoute == item.route,
      scheme: scheme,
      isDark: isDark,
      onTap: () {
        Navigator.pop(context);
        if (currentRoute != item.route) {
          Navigator.pushReplacementNamed(context, item.route);
        }
      },
    );
  }
}

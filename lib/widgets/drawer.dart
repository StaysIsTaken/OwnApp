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

  static const _navItems = [
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
      icon: Icons.settings_outlined,
      iconActive: Icons.settings_rounded,
      label: 'Einstellungen',
      route: AppRoutes.settings,
    ),
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
  ];

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
                  const DrawerSectionLabel(label: 'MENÜ'),
                  const SizedBox(height: 4),
                  ..._navItems.map(
                    (item) => DrawerNavTile(
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
                    ),
                  ),
                ],
              ),
            ),
            DrawerFooterWidget(scheme: scheme, isDark: isDark),
          ],
        ),
      ),
    );
  }
}

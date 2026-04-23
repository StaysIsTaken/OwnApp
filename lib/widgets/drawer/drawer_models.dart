class NavItem {
  final dynamic icon;
  final dynamic iconActive;
  final String label;
  final String route;
  final String? badge;

  const NavItem({
    required this.icon,
    required this.iconActive,
    required this.label,
    required this.route,
    this.badge,
  });
}

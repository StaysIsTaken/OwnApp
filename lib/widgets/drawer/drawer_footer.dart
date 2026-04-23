import 'package:flutter/material.dart';
import 'package:productivity/dataservice/login_service.dart';

class DrawerFooterWidget extends StatelessWidget {
  final ColorScheme scheme;
  final bool isDark;

  const DrawerFooterWidget({
    super.key,
    required this.scheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 18,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.07),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.primary.withOpacity(0.15),
            child: Icon(Icons.logout_rounded, size: 16, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: TextButton.icon(
              onPressed: () {
                LoginService.logout();
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false);
              },
              icon: Icon(Icons.logout_rounded, size: 16, color: scheme.primary),
              label: Text('Abmelden', style: TextStyle(color: scheme.primary)),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: isDark ? Colors.white30 : Colors.black26,
            size: 18,
          ),
        ],
      ),
    );
  }
}

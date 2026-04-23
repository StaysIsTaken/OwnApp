import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/User.dart';
import 'package:productivity/main.dart';
import 'package:productivity/provider/user_provider.dart';
import 'package:provider/provider.dart';

class DrawerHeaderWidget extends StatelessWidget {
  final ColorScheme scheme;
  final bool isDark;

  const DrawerHeaderWidget({
    super.key,
    required this.scheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    User? user = context.watch<UserProvider>().user;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 28,
        left: 24,
        right: 24,
        bottom: 28,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomRight: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(user: user),
          const SizedBox(height: 16),
          Text(
            '${user?.firstname} ${user?.lastname}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${user?.username}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          //const _ProBadge(),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final User? user;

  const _Avatar({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.2),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
      ),
      child: Center(
        child: Text(
          '${(user?.firstname.isNotEmpty ?? false) ? user!.firstname[0] : 'U'}${(user?.lastname.isNotEmpty ?? false) ? user!.lastname[0] : 'U'}'
              .toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, color: Colors.white, size: 13),
          SizedBox(width: 4),
          Text(
            'PRO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

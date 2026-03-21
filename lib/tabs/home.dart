import 'package:flutter/material.dart';
import 'package:productivity/main.dart';

class HomePage extends BasePage {
  const HomePage({super.key}) : super(title: 'Home');

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
    ),
  ];

  @override
  Widget buildBody(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Welcome!', style: text.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'This is your scalable Flutter starter.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 32),

          // Example Card using global theme
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.rocket_launch_outlined,
                    color: colors.primary,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text('Global Theme', style: text.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Colors, typography, and shapes are defined '
                    'once in AppTheme and apply everywhere.',
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

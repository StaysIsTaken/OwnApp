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
          const SizedBox(height: 12),

          // Recipes navigation card
          const SizedBox(height: 12),
          InkWell(
            onTap: () => Navigator.pushNamed(context, AppRoutes.recipes),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Icon(
                        Icons.menu_book_outlined,
                        color: colors.onSecondaryContainer,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rezepte', style: text.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            'Rezepte, Zutaten & Kategorien verwalten.',
                            style: text.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: colors.outline),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Work Log navigation card
          InkWell(
            onTap: () => Navigator.pushNamed(context, AppRoutes.workLog),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Icon(
                        Icons.assignment_outlined,
                        color: colors.onPrimaryContainer,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Arbeitsprotokoll', style: text.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            'Tasks erfassen, Start- & Endzeit protokollieren.',
                            style: text.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.outline,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Willkommen!', style: text.headlineLarge),
            const SizedBox(height: 8),
            Text(
              'Schnellzugriff zu Ihren wichtigsten Funktionen',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 32),

            // Main Modules Section
            Text('Hauptmodule', style: text.titleLarge),
            const SizedBox(height: 12),
            _buildNavigationCard(
              context,
              icon: Icons.menu_book_outlined,
              title: 'Rezepte',
              description: 'Rezepte verwalten',
              route: AppRoutes.recipes,
              containerColor: colors.secondaryContainer,
              iconColor: colors.onSecondaryContainer,
            ),
            const SizedBox(height: 12),
            _buildNavigationCard(
              context,
              icon: Icons.kitchen_outlined,
              title: 'Vorrat',
              description: 'Lebensmittelbestand verwalten',
              route: AppRoutes.pantry,
              containerColor: colors.secondaryContainer.withAlpha(180),
              iconColor: colors.onSecondaryContainer,
            ),
            const SizedBox(height: 12),
            _buildNavigationCard(
              context,
              icon: Icons.shopping_cart_outlined,
              title: 'Einkaufsliste',
              description: 'Einkäufe planen',
              route: AppRoutes.shoppingList,
              containerColor: colors.secondaryContainer.withAlpha(160),
              iconColor: colors.onSecondaryContainer,
            ),
            const SizedBox(height: 12),
            _buildNavigationCard(
              context,
              icon: Icons.today_outlined,
              title: 'Speiseplan',
              description: 'Mahlzeiten planen',
              route: AppRoutes.mealPlan,
              containerColor: colors.tertiaryContainer,
              iconColor: colors.onTertiaryContainer,
            ),
            const SizedBox(height: 12),
            _buildNavigationCard(
              context,
              icon: Icons.schedule_outlined,
              title: 'Zeiterfassung',
              description: 'Arbeitszeiten erfassen',
              route: AppRoutes.time,
              containerColor: colors.tertiaryContainer.withAlpha(180),
              iconColor: colors.onTertiaryContainer,
            ),
            const SizedBox(height: 12),
            _buildNavigationCard(
              context,
              icon: Icons.chat_outlined,
              title: 'Chat',
              description: 'Nachrichten und Chats',
              route: AppRoutes.chat,
              containerColor: colors.tertiaryContainer.withAlpha(160),
              iconColor: colors.onTertiaryContainer,
            ),
            const SizedBox(height: 32),

            // Master Data Section
            Text('Stammdaten', style: text.titleLarge),
            const SizedBox(height: 12),
            _buildNavigationCard(
              context,
              icon: Icons.category_outlined,
              title: 'Kategorien',
              description: 'Rezeptkategorien verwalten',
              route: AppRoutes.categories,
              containerColor: colors.surface,
              iconColor: colors.primary,
              isMasterData: true,
            ),
            const SizedBox(height: 12),
            _buildNavigationCard(
              context,
              icon: Icons.local_fire_department_outlined,
              title: 'Zutaten',
              description: 'Verfügbare Zutaten definieren',
              route: AppRoutes.ingredients,
              containerColor: colors.surface,
              iconColor: colors.primary,
              isMasterData: true,
            ),
            const SizedBox(height: 12),
            _buildNavigationCard(
              context,
              icon: Icons.straighten_outlined,
              title: 'Maßeinheiten',
              description: 'Maßeinheiten verwalten',
              route: AppRoutes.units,
              containerColor: colors.surface,
              iconColor: colors.primary,
              isMasterData: true,
            ),
            const SizedBox(height: 12),
            _buildNavigationCard(
              context,
              icon: Icons.storage_outlined,
              title: 'Lagerorte',
              description: 'Lagerverwaltung konfigurieren',
              route: AppRoutes.storageLocations,
              containerColor: colors.surface,
              iconColor: colors.primary,
              isMasterData: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String route,
    required Color containerColor,
    required Color iconColor,
    bool isMasterData = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: isMasterData
                      ? Border.all(color: colors.outline, width: 1)
                      : null,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: text.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

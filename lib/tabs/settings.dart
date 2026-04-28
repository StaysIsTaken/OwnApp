import 'package:flutter/material.dart';
import 'package:productivity/main.dart';
import 'package:productivity/widgets/settings_tile.dart';

import 'package:productivity/provider/settings_provider.dart';
import 'package:provider/provider.dart';

class SettingsPage extends BasePage {
  const SettingsPage({super.key}) : super(title: 'Einstellungen');

  @override
  Widget buildBody(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final settings = Provider.of<SettingsProvider>(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Dunkles Design verwenden'),
                value: settings.isDarkMode,
                onChanged: (v) => settings.setDarkMode(v),
                secondary: const Icon(Icons.dark_mode),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: Icon(Icons.access_time, color: colors.primary),
                title: const Text('24-Stunden-Format'),
                subtitle: const Text('Zeit als 24h oder 12h (AM/PM) anzeigen'),
                value: settings.use24hFormat,
                onChanged: (value) => settings.setUse24hFormat(value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SettingsTile(
          icon: Icons.info_outline,
          label: 'Über',
          subtitle: 'Version 1.0.0',
          iconColor: colors.secondary,
          onTap: () {},
        ),
      ],
    );
  }
}

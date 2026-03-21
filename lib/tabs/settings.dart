import 'package:flutter/material.dart';
import 'package:productivity/main.dart';
import 'package:productivity/widgets/settings_tile.dart';

class SettingsPage extends BasePage {
  const SettingsPage({super.key}) : super(title: 'Settings');

  @override
  Widget buildBody(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SettingsTile(
          icon: Icons.palette_outlined,
          label: 'Appearance',
          subtitle: 'Follows system theme (light / dark)',
          iconColor: colors.primary,
          onTap: () {},
        ),
        SettingsTile(
          icon: Icons.info_outline,
          label: 'About',
          subtitle: 'Version 1.0.0',
          iconColor: colors.secondary,
          onTap: () {},
        ),
      ],
    );
  }
}

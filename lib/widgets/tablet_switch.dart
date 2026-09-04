import 'package:flutter/material.dart';
import 'package:productivity/main.dart';
import 'package:productivity/provider/permission_provider.dart';
import 'package:productivity/provider/tablet_provider.dart';
import 'package:provider/provider.dart';

/// Der Schalter für den Küchenmodus.
///
/// Steht auf der Startseite und erscheint nur, wer ihn benutzen darf. Der
/// Zustand gehört zum **Gerät**, nicht zum Konto: dasselbe Konto meldet
/// sich am Tablet und am Telefon an, und nur das Tablet steht in der Küche.
class TabletSwitch extends StatelessWidget {
  const TabletSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final rechte = context.watch<PermissionProvider>();
    if (!rechte.darfTablet) return const SizedBox.shrink();

    final tablet = context.watch<TabletProvider>();
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: SwitchListTile(
        secondary: Icon(Icons.tablet_mac_rounded, color: colors.primary),
        title: const Text('Küchenmodus'),
        subtitle: const Text(
          'Große Ansicht für ein Gerät, das fest an einem Platz steht. '
          'Gilt nur für dieses Gerät.',
          style: TextStyle(fontSize: 12),
        ),
        value: tablet.an,
        onChanged: (an) async {
          await context.read<TabletProvider>().setzen(an);
          if (!context.mounted) return;
          // Beim Einschalten gleich hin – sonst müsste man raten, wo die
          // Ansicht jetzt ist.
          if (an) {
            Navigator.pushReplacementNamed(context, AppRoutes.tablet);
          }
        },
      ),
    );
  }
}

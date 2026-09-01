import 'package:flutter/material.dart';
import 'package:productivity/provider/permission_provider.dart';
import 'package:productivity/provider/user_provider.dart';
import 'package:provider/provider.dart';

/// Für Konten, die es gibt, aber die noch nichts dürfen.
///
/// Der Zustand ist gewollt: der Betreiber kann festlegen, dass neue Nutzer
/// keine Rolle bekommen und erst freigeschaltet werden. Ohne diesen Hinweis
/// stünde so jemand vor einer leeren App und wüsste nicht, ob sie kaputt ist
/// oder er selbst etwas falsch gemacht hat.
class NotActivatedView extends StatelessWidget {
  const NotActivatedView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = context.watch<UserProvider>().user?.firstname ?? '';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hourglass_empty_rounded,
                      size: 56, color: scheme.primary),
                  const SizedBox(height: 20),
                  Text(
                    name.isEmpty
                        ? 'Fast geschafft'
                        : 'Fast geschafft, $name',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Dein Konto ist angelegt, aber noch nicht freigeschaltet. '
                    'Sobald dir jemand mit Verwaltungsrechten eine Rolle '
                    'gibt, geht es hier weiter.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () =>
                        context.read<PermissionProvider>().laden(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Nochmal nachsehen'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.read<UserProvider>().logout(),
                    child: const Text('Abmelden'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

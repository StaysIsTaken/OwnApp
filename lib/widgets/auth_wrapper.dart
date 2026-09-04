import 'package:flutter/material.dart';
import 'package:productivity/provider/permission_provider.dart';
import 'package:productivity/provider/user_provider.dart';
import 'package:productivity/tabs/dashboard/dashboard_page.dart';
import 'package:productivity/tabs/login.dart';
import 'package:productivity/widgets/not_activated_view.dart';
import 'package:provider/provider.dart';

class AppAuthWrapper extends StatefulWidget {
  const AppAuthWrapper({super.key});

  @override
  State<AppAuthWrapper> createState() => _AppAuthWrapperState();
}

class _AppAuthWrapperState extends State<AppAuthWrapper> {
  /// Für wen die Rechte zuletzt geholt wurden. Ohne das würde bei jedem
  /// Neubau erneut geladen — und nach einem Nutzerwechsel gar nicht.
  String? _fuerNutzer;

  void _rechteHolen(UserProvider userProvider) {
    final id = userProvider.user?.id;
    final rechte = context.read<PermissionProvider>();

    if (id == null) {
      if (_fuerNutzer != null) {
        _fuerNutzer = null;
        rechte.leeren();
      }
      return;
    }
    if (_fuerNutzer == id) return;
    _fuerNutzer = id;
    // Nach dem Bauen, sonst würde mitten im Aufbau ein notifyListeners
    // ausgelöst.
    WidgetsBinding.instance.addPostFrameCallback((_) => rechte.laden());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        _rechteHolen(userProvider);
        if (!userProvider.isLoggedIn) return const Login();

        // Angemeldet, aber ohne jedes Recht: dann ist die App fuer diesen
        // Nutzer leer, und eine Erklaerung ist besser als eine leere Seite.
        // Faellt das Laden aus (kein Netz, altes Backend), gilt vorsorglich
        // "darf alles" – niemand soll wegen eines Netzfehlers ausgesperrt
        // wirken.
        if (context.watch<PermissionProvider>().istGesperrt) {
          return const NotActivatedView();
        }
        return const DashboardPage();
      },
    );
  }
}

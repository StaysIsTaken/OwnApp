import 'package:flutter/material.dart';
import 'package:productivity/provider/haushalt_provider.dart';
import 'package:productivity/provider/permission_provider.dart';
import 'package:productivity/provider/settings_provider.dart';
import 'package:productivity/provider/tablet_provider.dart';
import 'package:productivity/provider/user_provider.dart';
import 'package:productivity/tabs/tablet/tablet_dashboard.dart';
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

  /// Rechte, Haushalt und Einstellungen beim Anmelden holen, beim
  /// Abmelden wegwerfen.
  ///
  /// Alles drei hängt am selben Zeitpunkt: es gilt pro Konto. Der
  /// Haushalt kommt hier und nicht auf seiner Seite her, weil ihn das
  /// **Menü** braucht — und weil so auch eine offene Einladung ankommt,
  /// ohne dass es dafür einen zweiten Weg braucht.
  ///
  /// Die Einstellungen kommen aus demselben Grund hier her: sie hängen
  /// am Konto, und die App zeigt bis dahin den Stand des Geräts.
  void _rechteHolen(UserProvider userProvider) {
    final id = userProvider.user?.id;
    final rechte = context.read<PermissionProvider>();
    final haushalt = context.read<HaushaltProvider>();
    final einstellungen = context.read<SettingsProvider>();

    if (id == null) {
      if (_fuerNutzer != null) {
        _fuerNutzer = null;
        rechte.leeren();
        haushalt.leeren();
      }
      return;
    }
    if (_fuerNutzer == id) return;
    _fuerNutzer = id;
    // Nach dem Bauen, sonst würde mitten im Aufbau ein notifyListeners
    // ausgelöst.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      rechte.laden();
      haushalt.laden();
      einstellungen.vomKonto();
    });
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

        // Ein Gerät im Küchenmodus startet direkt dorthin. Sonst müsste
        // jemand nach jedem Neustart erst durch die App navigieren – und
        // das Tablet hängt an der Wand.
        final tablet = context.watch<TabletProvider>();
        final rechte = context.watch<PermissionProvider>();
        if (tablet.geladen && tablet.an && rechte.darfTablet) {
          return const TabletDashboard();
        }
        return const DashboardPage();
      },
    );
  }
}

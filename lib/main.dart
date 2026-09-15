import 'dart:async';
import 'package:flutter/material.dart';
import 'package:productivity/dataservice/mitteilungs_ziel.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:productivity/provider/user_provider.dart';
import 'package:productivity/provider/settings_provider.dart';
import 'package:productivity/tabs/dashboard/dashboard_page.dart';
import 'package:productivity/tabs/login.dart';
import 'package:productivity/tabs/recipes/manage_categories_page.dart';
import 'package:productivity/tabs/recipes/manage_ingredients_page.dart';
import 'package:productivity/tabs/recipes/manage_units_page.dart';
import 'package:productivity/tabs/register.dart';
import 'package:productivity/tabs/settings.dart';
import 'package:productivity/tabs/settings/stimme_page.dart';
import 'package:productivity/tabs/recipes/recipes_page.dart';
import 'package:productivity/tabs/pantry/pantry_page.dart';
import 'package:productivity/dataservice/erinnerungs_abgleich.dart';
import 'package:productivity/provider/timer_provider.dart';
import 'package:productivity/tabs/einkauf/einkaufslisten_page.dart';
import 'package:productivity/tabs/finanzen/finanzen_page.dart';
import 'package:productivity/tabs/haushalt/haushalt_finanzen_page.dart';
import 'package:productivity/tabs/haushalt/haushalt_page.dart';
import 'package:productivity/tabs/finanzen/kassen_page.dart';
import 'package:productivity/tabs/finanzen/serien_page.dart';
import 'package:productivity/tabs/einkauf/laeden_page.dart';
import 'package:productivity/tabs/einkauf/preise_page.dart';
import 'package:productivity/tabs/pantry/meal_plan_page.dart';
import 'package:productivity/tabs/pantry/manage_storage_locations_page.dart';
import 'package:productivity/tabs/chat/chat_page.dart';
import 'package:productivity/tabs/tasks.dart';

import 'package:productivity/tabs/time.dart';
import 'package:productivity/tabs/notes/notes_page.dart';
import 'package:productivity/tabs/journal/journal_page.dart';
import 'package:productivity/tabs/planner/planner_tab.dart';
import 'package:productivity/tabs/planner/manage_planner_types_page.dart';
import 'package:productivity/tabs/planner/kalender_verwalten_page.dart';
import 'package:productivity/tabs/assistant/assistant_page.dart';
import 'package:productivity/tabs/admin/admin_page.dart';
import 'package:productivity/tabs/tablet/tablet_dashboard.dart';
import 'package:productivity/widgets/assistant_overlay.dart';
import 'package:flutter/foundation.dart';
import 'package:productivity/widgets/drawer.dart';
import 'package:productivity/widgets/auth_wrapper.dart';
import 'package:productivity/dataservice/notification_service.dart';
import 'package:productivity/dataservice/server_config.dart';
import 'package:productivity/dataservice/local_notification_manager.dart';
import 'package:productivity/dataservice/background_task_manager.dart';
import 'package:productivity/provider/planner_provider.dart';
import 'package:productivity/provider/chat_provider.dart';
import 'package:productivity/provider/haushalt_provider.dart';
import 'package:productivity/provider/permission_provider.dart';
import 'package:productivity/provider/tablet_provider.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de_DE', null);

  // Die eingestellte Serveradresse gilt ab jetzt. Muss VOR allem anderen
  // stehen: der NotificationService baut seine WebSocket-Adresse daraus ab.
  await ServerConfig.anwenden();

  // Initialize local notifications (works on iOS/Android, no-op on web)
  if (!kIsWeb) {
    await LocalNotificationManager().init();
    // Beim Kaltstart feuert der Tipp-Rueckruf nicht: die App lief nicht,
    // als getippt wurde. Der Grund steht nur hier.
    await LocalNotificationManager().startgrundPruefen();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => PlannerProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => PermissionProvider()),
        // App-weit und nicht an der Haushaltsseite: das MENUE muss
        // wissen, ob es den Abschnitt ueberhaupt zeigt, und an privaten
        // Zustand einer Seite kommt es nicht heran.
        ChangeNotifierProvider(create: (_) => HaushaltProvider()),
        ChangeNotifierProvider(create: (_) => TabletProvider()),
        // App-weit, nicht an der Uhrkachel: der Timer laeuft weiter,
        // waehrend man blaettert, und die Sprache stellt ihn von aussen.
        ChangeNotifierProvider(create: (_) => TimerProvider()),
      ],
      child: const _ErinnerungenNachziehen(
        child: _MitteilungsSpringer(child: MyApp()),
      ),
    ),
  );

  // WebSocket-based real-time notifications (was already there)
  NotificationService().init();

  // Background work for offline reminders. Init AFTER runApp so the UI
  // shows up immediately even if the platform plugin is slow.
  if (!kIsWeb) {
    // Ask the user for permission once at startup. If they decline, they can
    // re-enable from the settings page later.
    LocalNotificationManager().requestPermissions();
    BackgroundTaskManager.init();
  }
}

/// Hält die vorgemerkten Erinnerungen aktuell.
///
/// Zwei Auslöser, die vorher fehlten: der Start der App und die Rückkehr in
/// den Vordergrund. Bis hierher tat das nur der Hintergrundlauf alle sechs
/// Stunden — auf Android verlässlich, auf iOS nicht: dort ist der
/// Hintergrundlauf eine Bitte und kein Versprechen. Ein Termin, den ein
/// anderes Gerät angelegt hatte, konnte auf dem iPhone unbemerkt
/// durchrutschen.
///
/// Sitzt bewusst um die ganze App herum und nicht in einer einzelnen Seite:
/// der Lebenszyklus gehört der App, nicht dem Kalender.
class _ErinnerungenNachziehen extends StatefulWidget {
  final Widget child;

  const _ErinnerungenNachziehen({required this.child});

  @override
  State<_ErinnerungenNachziehen> createState() =>
      _ErinnerungenNachziehenState();
}

class _ErinnerungenNachziehenState extends State<_ErinnerungenNachziehen> {
  AppLifecycleListener? _lebenszyklus;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return; // Der Browser kann nichts vormerken.

    // Beim Start erzwungen: wer die App aufmacht, hat oft gerade auf einem
    // anderen Geraet etwas eingetragen.
    unawaited(ErinnerungsAbgleich.jetzt(erzwingen: true));

    // Beim Zurueckkommen nicht erzwungen — das passiert bei jedem Wechsel
    // zwischen zwei Apps, und die Ruhezeit faengt das Haeufige ab.
    _lebenszyklus = AppLifecycleListener(
      onResume: () => unawaited(ErinnerungsAbgleich.jetzt()),
    );
  }

  @override
  void dispose() {
    _lebenszyklus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Springt zu dem, was in der angetippten Mitteilung stand.
///
/// Getrennt vom Merken (siehe [MitteilungsZiel]), weil das Ziel zu einem
/// Zeitpunkt eintreffen kann, zu dem es noch keinen Navigator gibt: beim
/// Kaltstart steht der Grund fest, bevor das erste Bild gezeichnet ist.
class _MitteilungsSpringer extends StatefulWidget {
  final Widget child;

  const _MitteilungsSpringer({required this.child});

  @override
  State<_MitteilungsSpringer> createState() => _MitteilungsSpringerState();
}

class _MitteilungsSpringerState extends State<_MitteilungsSpringer> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    MitteilungsZiel.beiNeuemZiel = _springen;
    WidgetsBinding.instance.addPostFrameCallback((_) => _springen());
  }

  @override
  void dispose() {
    MitteilungsZiel.beiNeuemZiel = null;
    super.dispose();
  }

  void _springen() {
    final termin = MitteilungsZiel.terminAus(MitteilungsZiel.abholen());
    if (termin == null) return;
    // Nach dem Frame: beim Kaltstart steht der Navigator hier noch nicht.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MitteilungsZiel.navigator.currentState?.pushNamed(
        AppRoutes.planner,
        arguments: PlannerZiel(entryId: termin),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return MaterialApp(
          title: 'Productivity App',
          scaffoldMessengerKey: NotificationService.messengerKey,
          // Aus dem statischen Rueckruf des Mitteilungs-Plugins gibt es
          // keinen BuildContext — der Schluessel ist der Weg dorthin.
          navigatorKey: MitteilungsZiel.navigator,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const AppAuthWrapper(),
          routes: AppRoutes.routes,
          builder: (context, child) =>
              GlobalAssistantOverlay(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  Theme Configuration
// ─────────────────────────────────────────────
class AppTheme {
  // Design Constants
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 24.0;

  static const Color primaryColor = Colors.blue;
  static const Color secondaryColor = Colors.lightBlueAccent;

  static final light = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: primaryColor,
    brightness: Brightness.light,
  );
  static final dark = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: primaryColor,
    brightness: Brightness.dark,
  );
}

// ─────────────────────────────────────────────
//  Routing
// ─────────────────────────────────────────────
class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String dashboard = '/dashboard';
  static const String settings = '/settings';
  static const String stimme = '/settings/stimme';

  static const String recipes = '/recipes';
  static const String time = '/time';
  static const String tasks = '/tasks';
  static const String categories = '/categories';
  static const String ingredients = '/ingredients';
  static const String units = '/units';

  // New Modules
  static const String pantry = '/pantry';
  static const String einkauf = '/einkauf';
  static const String laeden = '/laeden';
  static const String preise = '/preise';
  static const String mealPlan = '/meal-plan';
  static const String chat = '/chat';
  static const String storageLocations = '/storage-locations';

  // Haushaltsbuch. Der Pfad heisst `/finanzen`, die Seite
  // „Haushaltsbuch" -- „Finanzen" klingt nach Vermoegensverwaltung,
  // und das ist es nicht.
  static const String finanzen = '/finanzen';
  static const String kassen = '/finanzen/kassen';
  static const String finanzSerien = '/finanzen/serien';

  // Haushalte. Kein Menuepunkt fuer den, der in keinem ist -- der Weg
  // hierher fuehrt dann nur ueber die Einstellungen.
  static const String haushalt = '/haushalt';
  static const String haushaltFinanzen = '/haushalt/finanzen';

  // Knowledge Management
  static const String notes = '/notes';
  static const String journal = '/journal';
  static const String planner = '/planner';
  static const String plannerTypes = '/planner-types';
  static const String kalender = '/kalender';
  static const String assistant = '/assistant';
  static const String admin = '/admin';
  static const String tablet = '/tablet';

  static final Map<String, WidgetBuilder> routes = {
    login: (_) => const Login(),
    register: (_) => const RegisterPage(),
    home: (_) => const DashboardPage(),
    dashboard: (_) => const DashboardPage(),
    settings: (_) => const SettingsPage(),
    stimme: (_) => const StimmePage(),

    recipes: (_) => const RecipesPage(),
    time: (_) => const TimePage(),
    tasks: (_) => const TasksPage(),
    categories: (_) => const ManageCategoriesPage(),
    ingredients: (_) => const ManageIngredientsPage(),
    units: (_) => const ManageUnitsPage(),
    storageLocations: (_) => const ManageStorageLocationsPage(),

    // New Modules
    pantry: (_) => const PantryPage(),
    finanzen: (_) => const FinanzenPage(),
    kassen: (_) => const KassenPage(),
    finanzSerien: (_) => const SerienPage(),
    haushalt: (_) => const HaushaltPage(),
    haushaltFinanzen: (_) => const HaushaltFinanzenPage(),
    einkauf: (_) => const EinkaufslistenPage(),
    laeden: (_) => const LaedenPage(),
    preise: (_) => const PreisePage(),
    mealPlan: (_) => const MealPlanPage(),
    chat: (_) => const ChatPage(),

    // Knowledge Management
    notes: (_) => const NotesPage(),
    journal: (_) => const JournalPage(),
    planner: (_) => const PlannerTab(),
    plannerTypes: (_) => const ManagePlannerTypesPage(),
    kalender: (_) => const KalenderVerwaltenPage(),
    assistant: (_) => const AssistantPage(),
    admin: (_) => const AdminPage(),
    tablet: (_) => const TabletDashboard(),
  };
}

// ─────────────────────────────────────────────
//  Base Page – extend this for every new page
// ─────────────────────────────────────────────
abstract class BasePage extends StatelessWidget {
  final String title;
  final bool requiresLogin;

  const BasePage({super.key, required this.title, this.requiresLogin = true});

  /// Override this to build the page body.
  Widget buildBody(BuildContext context);

  /// Override to add AppBar actions.
  List<Widget>? buildActions(BuildContext context) => null;

  /// Override to add a FAB.
  Widget? buildFAB(BuildContext context) => null;

  Widget? buildDrawer(BuildContext context) => const DrawerWidget();

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isLoggedIn = userProvider.isLoggedIn;

    return Scaffold(
      appBar: AppBar(title: Text(title), actions: buildActions(context)),
      body: SafeArea(
        child: (requiresLogin && !isLoggedIn)
            ? _LoginRequiredView(pageTitle: title)
            : buildBody(context),
      ),
      floatingActionButton: (requiresLogin && !isLoggedIn)
          ? null
          : buildFAB(context),
      drawer: buildDrawer(context),
    );
  }
}

class _LoginRequiredView extends StatelessWidget {
  final String pageTitle;
  const _LoginRequiredView({required this.pageTitle});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_person_outlined,
                size: 80,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Anmeldung erforderlich',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Um auf "$pageTitle" zugreifen zu können, musst du angemeldet sein. So bleiben deine Daten geschützt und synchronisiert.',
              style: text.bodyLarge?.copyWith(color: colors.outline),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () {
                // Hier zum Login navigieren (angenommen Route ist '/')
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false);
              },
              icon: const Icon(Icons.login),
              label: const Text('Jetzt anmelden'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                // Optional: Zurück zur Startseite oder ähnliches
                Navigator.of(context).pop();
              },
              child: const Text('Später'),
            ),
          ],
        ),
      ),
    );
  }
}

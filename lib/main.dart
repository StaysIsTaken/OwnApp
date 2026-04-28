import 'package:flutter/material.dart';
import 'package:productivity/provider/user_provider.dart';
import 'package:productivity/provider/settings_provider.dart';
import 'package:productivity/tabs/home.dart';
import 'package:productivity/tabs/login.dart';
import 'package:productivity/tabs/recipes/manage_categories_page.dart';
import 'package:productivity/tabs/recipes/manage_ingredients_page.dart';
import 'package:productivity/tabs/recipes/manage_units_page.dart';
import 'package:productivity/tabs/register.dart';
import 'package:productivity/tabs/settings.dart';
import 'package:productivity/tabs/recipes/recipes_page.dart';
import 'package:productivity/tabs/pantry/pantry_page.dart';
import 'package:productivity/tabs/pantry/shopping_list_page.dart';
import 'package:productivity/tabs/pantry/meal_plan_page.dart';
import 'package:productivity/tabs/pantry/manage_storage_locations_page.dart';
import 'package:productivity/tabs/chat/chat_page.dart';

import 'package:productivity/tabs/time.dart';
import 'package:productivity/widgets/drawer.dart';
import 'package:productivity/widgets/auth_wrapper.dart';
import 'package:productivity/dataservice/notification_service.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const MyApp(),
    ),
  );
  NotificationService().init();
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
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const AppAuthWrapper(),
          routes: AppRoutes.routes,
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
  static const String settings = '/settings';

  static const String recipes = '/recipes';
  static const String time = '/time';
  static const String categories = '/categories';
  static const String ingredients = '/ingredients';
  static const String units = '/units';

  // New Modules
  static const String pantry = '/pantry';
  static const String shoppingList = '/shopping-list';
  static const String mealPlan = '/meal-plan';
  static const String chat = '/chat';
  static const String storageLocations = '/storage-locations';

  static final Map<String, WidgetBuilder> routes = {
    register: (_) => const RegisterPage(),
    home: (_) => const HomePage(),
    settings: (_) => const SettingsPage(),

    recipes: (_) => const RecipesPage(),
    time: (_) => const TimePage(),
    categories: (_) => const ManageCategoriesPage(),
    ingredients: (_) => const ManageIngredientsPage(),
    units: (_) => const ManageUnitsPage(),
    storageLocations: (_) => const ManageStorageLocationsPage(),

    // New Modules
    pantry: (_) => const PantryPage(),
    shoppingList: (_) => const ShoppingListPage(),
    mealPlan: (_) => const MealPlanPage(),
    chat: (_) => const ChatPage(),
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
      floatingActionButton: (requiresLogin && !isLoggedIn) ? null : buildFAB(context),
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
                color: colors.primaryContainer.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_person_outlined, size: 80, color: colors.primary),
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
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              },
              icon: const Icon(Icons.login),
              label: const Text('Jetzt anmelden'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

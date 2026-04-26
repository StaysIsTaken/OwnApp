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

import 'package:productivity/tabs/time.dart';
import 'package:productivity/widgets/drawer.dart';
import 'package:productivity/widgets/auth_wrapper.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────
//  Entry Point
// ─────────────────────────────────────────────
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const MainApp(),
    ),
  );
}

// ─────────────────────────────────────────────
//  App Root
// ─────────────────────────────────────────────
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      debugShowCheckedModeBanner: false,

      // ── Global Themes ──────────────────────
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system, // Follows OS setting
      // ── Routing ────────────────────────────
      home: const AppAuthWrapper(),
      routes: AppRoutes.routes,
    );
  }
}

// ─────────────────────────────────────────────
//  Global Theme
//  Usage anywhere:  Theme.of(context).colorScheme.primary
//                   AppTheme.primaryColor
// ─────────────────────────────────────────────
class AppTheme {
  AppTheme._(); // Prevent instantiation

  // ── Brand Colors ───────────────────────────
  static const Color primaryColor = Color.fromARGB(255, 81, 72, 249);
  static const Color secondaryColor = Color.fromARGB(255, 10, 80, 92);
  static const Color errorColor = Color(0xFFCF6679);

  // ── Shared shape / radius ──────────────────
  static const double radiusSm = 8.0;
  static const double radiusMd = 14.0;
  static const double radiusLg = 24.0;

  // ── Shared text styles ─────────────────────
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // ── Light Theme ────────────────────────────
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      brightness: Brightness.light,
    ),
    textTheme: _buildTextTheme(Colors.black87),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSm),
      ),
    ),
  );

  // ── Dark Theme ─────────────────────────────
  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      brightness: Brightness.dark,
    ),
    textTheme: _buildTextTheme(Colors.white),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Color(0xFF1E1E2E),
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF2A2A3E),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2A2A3E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSm),
      ),
    ),
  );

  // ── Shared TextTheme builder ───────────────
  static TextTheme _buildTextTheme(Color baseColor) {
    return TextTheme(
      headlineLarge: headlineLarge.copyWith(color: baseColor),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: baseColor),
      bodyMedium: bodyMedium.copyWith(color: baseColor),
      bodySmall: TextStyle(fontSize: 13, color: baseColor.withOpacity(0.7)),
    );
  }
}

// ─────────────────────────────────────────────
//  Routes
//  Add new pages here – one central place.
// ─────────────────────────────────────────────
class AppRoutes {
  AppRoutes._();

  static const String login = '/';
  static const String register = '/register';
  static const String home = '/home';
  static const String settings = '/settings';

  static const String recipes = '/recipes';
  static const String time = '/time';
  static const String categories = '/categories';
  static const String ingredients = '/ingredients';
  static const String units = '/units';
  // Add more route names here …

  static final Map<String, WidgetBuilder> routes = {
    register: (_) => const RegisterPage(),
    home: (_) => const HomePage(),
    settings: (_) => const SettingsPage(),

    recipes: (_) => const RecipesPage(),
    time: (_) => const TimePage(),
    categories: (_) => const ManageCategoriesPage(),
    ingredients: (_) => const ManageIngredientsPage(),
    units: (_) => const ManageUnitsPage(),
    // Register new pages here …
  };
}

// ─────────────────────────────────────────────
//  Base Page – extend this for every new page
// ─────────────────────────────────────────────
abstract class BasePage extends StatelessWidget {
  final String title;
  const BasePage({super.key, required this.title});

  /// Override this to build the page body.
  Widget buildBody(BuildContext context);

  /// Override to add AppBar actions.
  List<Widget>? buildActions(BuildContext context) => null;

  /// Override to add a FAB.
  Widget? buildFAB(BuildContext context) => null;

  Widget? buildDrawer(BuildContext context) => DrawerWidget();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: buildActions(context)),
      body: SafeArea(child: buildBody(context)),
      floatingActionButton: buildFAB(context),
      drawer: buildDrawer(context),
    );
  }
}

# Productivity App

Eine Flutter-Anwendung mit modernem Design und globalem Theme-System.

---

## Global Theme System

Das App-Theme ist zentral in `lib/main.dart` definiert und funktioniert nach dem **Single Source of Truth**-Prinzip.

### Wie es funktioniert

**1. Theme-Definition (AppTheme-Klasse)**

```dart
class AppTheme {
  // Brand Colors
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color secondaryColor = Color(0xFF03DAC6);
  
  // Radius
  static const double radiusMd = 14.0;
  
  // Light & Dark Themes
  static final ThemeData light = ThemeData(/* ... */);
  static final ThemeData dark = ThemeData(/* ... */);
}
```

**2. App konfiguriert das Theme**

```dart
MaterialApp(
  theme: AppTheme.light,           // Helles Theme
  darkTheme: AppTheme.dark,        // Dunkles Theme
  themeMode: ThemeMode.system,     // Folgt OS-Einstellung
)
```

**3. Im gesamten Code verwenden**

```dart
// In jedem Widget verfügbar:
Color primary = Theme.of(context).colorScheme.primary;
Color custom = AppTheme.primaryColor;
double radius = AppTheme.radiusMd;
```

### Wichtige Komponenten

| Komponente | Beschreibung |
|-----------|-------------|
| **Brand Colors** | `primaryColor`, `secondaryColor`, `errorColor` – Basis-Farben |
| **Radius** | `radiusSm` (8px), `radiusMd` (14px), `radiusLg` (24px) – konsistente Ecken |
| **TextTheme** | Vordefinierte Text-Stile (`headlineLarge`, `bodyMedium`, etc.) |
| **AppBarTheme** | Look & Feel der oberen Leiste |
| **InputDecorationTheme** | Einheitliches Aussehen für Text-Eingabefelder |
| **ElevatedButtonTheme** | Design für Buttons |

### Automatische Hell/Dunkel-Anpassung

Das System hat zwei komplette Themes:
- **Light Theme**: Hell mit weißem Hintergrund
- **Dark Theme**: Dunkel mit grauem Hintergrund

Die App erkennt automatisch die OS-Einstellung und passt sich an – keine manuelle Umschaltung nötig!

### Neue Design-Elemente hinzufügen

Farbe benötigt? → `AppTheme.primaryColor`
Abstand/Radius? → `AppTheme.radiusMd`
Text-Stil? → `Theme.of(context).textTheme.headlineLarge`

Neue Farbe hinzufügen:
```dart
static const Color accentColor = Color(0xFFFF6B6B);
```

Neuer Radius:
```dart
static const double radiusXl = 32.0;
```

Das System kümmert sich automatisch um Light/Dark-Konsistenz! 🎨

# Productivity App - Flutter

Eine umfassende Flutter-Anwendung für persönliche Produktivitätsmanagement mit Aufgabenverwaltung, einem Kalender-/Planner-Modul (inkl. wiederkehrender Termine), Rezepten, Vorratsverwaltung, Essensplanung, Zeitverfolgung, Notizen, Journal und Echtzeit-Chat.

## 🎯 Features

### Task Management (Kanban Board)
- **Kanban-Board**: Organisiere Aufgaben in drei Spalten: "Zu tun", "In Bearbeitung", "Fertig"
- **Drag & Drop**: Verschiebe Aufgaben zwischen Spalten zum Verwalten des Workflows
- **Aufgabendetails**:
  - Titel und optionale Beschreibung
  - Fälligkeitsdatum
  - Prioritätsstufen (Niedrig, Mittel, Hoch, Dringend)
  - Kategorievergabe
  - Benutzerzuordnung (automatisch auf aktuellen Benutzer gesetzt)
  - Abschluss-Status
- **Benutzerzuweisung**: Anzeigen und Ändern des zugeordneten Benutzers
- **Aufgabenaktionen**: Bearbeiten, Löschen und Abschluss-Status direkt vom Board

### 🗓️ Planner (Kalender)
- **Drei Ansichten**: Woche, Monat und Tag
- **Wochenansicht**: Tagesraster über volle Breite mit durchlaufendem Zeitstrahl (00–24 Uhr), "Jetzt"-Linie wie in Teams/Google Calendar, Hervorhebung des heutigen Tages
- **Termine mit Start- und Endzeit**: Anlegen über Klick auf eine Rasterzelle oder den + Button; Dauer wird automatisch berechnet
- **Drag & Drop**:
  - Wochenansicht: Termin ziehen ändert die Uhrzeit (15-Min-Raster) und den Tag
  - Monatsansicht: Termin auf einen anderen Tag ziehen verschiebt das Datum
- **Bearbeiten & Löschen** direkt aus Wochen-, Monats- und Tagesansicht
- **Typen als Stammdaten**: Termin-Typen (z.B. Aufgabe, Meeting, Erinnerung) sind frei pflegbar (Name + Farbe) statt fest verdrahtet; eigener Verwaltungs-Screen
- **Wiederkehrende Termine (Serien)**:
  - Täglich / Wöchentlich (mit Wochentagsauswahl) / Monatlich / Jährlich, mit Intervall ("alle N …")
  - Ende per Datum, nach Anzahl oder unbegrenzt
  - Beim Bearbeiten/Löschen Auswahl des Geltungsbereichs: **Nur dieser / Dieser und folgende / Alle**
  - 🔁-Markierung an Serienterminen; einzeln verschobene Termine bleiben erhalten
- **Benachrichtigungen**: Konfigurierbare Vorlaufzeit pro Termin

### 📖 Rezeptverwaltung
- **Rezept-Browsing**: Anzeigen und Verwalten von Rezepten mit Zutaten
- **Kategorieverwaltung**: Organisiere Rezepte nach Kategorien
- **Zutatenverwaltung**: Verwalte eine Zutatendatenbank
- **Einheitenverwaltung**: Definiere Maßeinheiten für Zutaten
- **Rezeptsuche**: Finde Rezepte nach Kategorie oder Suchkriterien

### 🥫 Vorratsverwaltung
- **Bestandsverfolgung**: Behalte Vorratselemente mit Mengen im Überblick
- **Lagerorte**: Organisiere Elemente nach Lagerlokation
- **Mindestmengen-Warnung**: Überwache Mindestmengen-Schwellwerte
- **Einkaufslisten-Integration**: Verknüpfung mit Einkaufslisten

### 🛒 Einkaufsliste
- **Listenverwaltung**: Erstelle und verwalte Einkaufslisten
- **Elementverwaltung**: Füge Elemente mit Mengen hinzu
- **Vorrats-Synchronisation**: Abgleich mit Vorratsinventar
- **Status-Verfolgung**: Markiere gekaufte Elemente

### 🍽️ Essensplaner
- **Wochenplanung**: Plane Mahlzeiten für die Woche
- **Rezept-Integration**: Ordne Rezepte zu Mahlzeiten
- **Zutatenverfolgung**: Automatische Verfolgung benötigter Zutaten
- **Einkaufslisten-Generierung**: Generiere Einkaufslisten basierend auf Plänen

### ⏱️ Zeitverfolgung
- **Zeiteintrag-Verwaltung**: Erstelle und verfolge Zeiteinträge
- **Start-/Endzeiten**: Erfasse Anfangs- und Endzeiten
- **Aktive Einträge beenden**: Beende aktive Einträge mit einem Klick
- **Dauer-Berechnung**: Automatische Berechnung der aufgewendeten Zeit
- **Aktivitäts-Kategorisierung**: Ordne Kategorien zu

### 💬 Chat
- **Echtzeit-Messaging**: Chat mit WebSocket-Unterstützung
- **Benutzer-zu-Benutzer**: Sende Nachrichten an andere Benutzer
- **Nachrichtenhistorie**: Zugriff auf Chat-Verlauf
- **Echtzeit-Updates**: Nachrichten aktualisieren sich in Echtzeit

### 📝 Notizen & 📔 Journal
- **Notizen**: Notizen in Ordnern organisieren und verknüpfen
- **Journal**: Tagebuch-Einträge mit Auswertungen/Analysen

### ⚙️ Einstellungen
- **Design-Anpassung**: Wechsel zwischen Hell- und Dunkelmodus
- **Benutzereinstellungen**: Personalisiere App-Verhalten
- **Kontoeinstellungen**: Verwalte Benutzerprofilinformationen

### 🔐 Authentifizierung
- **Benutzer-Registrierung**: Erstelle neue Konten
- **Login-System**: Sichere Authentifizierung mit Session-Verwaltung
- **Benutzerverwaltung**: Sieh alle registrierten Benutzer
- **Session-Persistierung**: Behalte Login-Status über Neustart

## 📁 Projektstruktur

```
lib/
├── main.dart                          # App-Einstiegspunkt, Routing, Theme
├── dataclasses/                       # Datenmodelle
│   ├── task.dart                     # Task-Modell mit Kanban-Status
│   ├── user.dart                     # Benutzer-Authentifizierungs-Modell
│   └── [weitere Modelle]             # Rezept, Vorrät, Zeiteintrag
├── dataservice/                       # API-Integrations-Schicht
│   ├── api_client.dart               # Dio HTTP-Client Konfiguration
│   ├── task_service.dart             # Task CRUD-Operationen
│   ├── user_service.dart             # Benutzerverwaltung
│   ├── login_service.dart            # Authentifizierung
│   └── [weitere Services]            # Rezept, Vorrät, Chat
├── provider/                          # State Management
│   ├── user_provider.dart            # Authentifizierungs-Status
│   ├── settings_provider.dart        # App-Einstellungen und Design
│   └── [weitere Provider]            # Task, Vorrät, Chat-Status
├── tabs/                              # Seiten-Implementierungen
│   ├── home.dart                     # Startseite
│   ├── login.dart                    # Login-Seite
│   ├── register.dart                 # Registrierungs-Seite
│   ├── tasks.dart                    # Kanban-Board
│   ├── time.dart                     # Zeitverfolgung
│   ├── recipes/                      # Rezept-Seiten
│   ├── pantry/                       # Vorrats-Seiten
│   ├── chat/                         # Chat-Interface
│   ├── planner/                      # Planner/Kalender
│   │   ├── planner_tab.dart          # Haupt-Tab (Woche/Monat/Tag)
│   │   ├── views/                    # week_view, month_view, day_view
│   │   ├── widgets/                  # Eintrags-Dialog & -Karte
│   │   └── manage_planner_types_page.dart  # Typen-Stammdaten
│   ├── notes/                        # Notizen
│   ├── journal/                      # Journal
│   ├── calendar/                     # Kalender
│   └── settings.dart                 # Einstellungen
├── widgets/                           # Wiederverwendbare UI-Komponenten
│   ├── drawer.dart                   # Navigations-Schublade
│   ├── drawer/                       # Schublade-Unterkomponenten
│   │   ├── drawer_header.dart
│   │   ├── drawer_footer.dart
│   │   ├── drawer_nav_tile.dart
│   │   └── drawer_models.dart
│   ├── auth_wrapper.dart             # Auth-State Wrapper
│   └── [weitere Widgets]             # Task-Karten, Formulare
└── assets/                            # Bilder und Symbole
```

## 🛠️ Technologie-Stack

### Frontend
- **Flutter**: 3.11.1+ - Cross-Platform Mobile Framework
- **Provider**: 6.1.5+ - State Management
- **Material Design 3**: Modernes Design-System mit Material You

### Backend-Integration
- **Dio**: 5.9.2 - HTTP-Client für REST API
- **WebSocket**: 3.0.3 - Echtzeit-Chat
- **HTTP**: 1.6.0 - Zusätzliche HTTP-Utilities

### Utilities
- **Intl**: 0.19.0 - Internationalisierung und Datums-Formatierung
- **SharedPreferences**: 2.5.4 - Lokale Datenspeicherung

## 🚀 Installation & Einrichtung

### Voraussetzungen
- Flutter SDK 3.11.1 oder höher
- Dart SDK 3.11.1 oder höher
- Android SDK (für Android-Entwicklung)
- Xcode (für iOS-Entwicklung)
- Git

### Schritte

1. **Repository klonen**
   ```bash
   git clone <repository-url>
   cd OwnApp
   ```

2. **Abhängigkeiten installieren**
   ```bash
   flutter pub get
   ```

3. **API-Verbindung konfigurieren**
   - Bearbeite `lib/dataservice/api_client.dart`
   - Setze die `baseUrl` zu deinem Backend API-Endpoint:
     ```dart
     static const String baseUrl = 'http://your-api-url:port';
     ```

4. **App ausführen**
   ```bash
   flutter run
   ```

   Oder für spezifische Plattformen:
   ```bash
   flutter run -d android  # Android
   flutter run -d ios      # iOS
   ```

## 🌐 API-Integration

Die App kommuniziert mit einem REST-API-Backend.

### Authentifizierung
- `POST /auth/login` - Benutzer-Login
- `POST /auth/register` - Benutzer-Registrierung
- `POST /auth/logout` - Logout

### Tasks
- `GET /tasks` - Liste Aufgaben mit Filtern auf
- `GET /tasks/pending` - Liste unvollständige Aufgaben auf
- `GET /tasks/{id}` - Hole Aufgabendetails
- `POST /tasks` - Erstelle neue Aufgabe
- `PUT /tasks/{id}` - Aktualisiere Aufgabe
- `PATCH /tasks/{id}/toggle` - Wechsel Abschluss-Status
- `DELETE /tasks/{id}` - Lösche Aufgabe

### Benutzer
- `GET /users` - Liste alle Benutzer auf
- `GET /users/{id}` - Hole Benutzerdetails
- `POST /users` - Erstelle Benutzer

### Zeiteinträge
- `GET /time-entries` - Liste Zeiteinträge auf
- `POST /time-entries` - Erstelle Eintrag
- `PUT /time-entries/{id}` - Aktualisiere Eintrag
- `DELETE /time-entries/{id}` - Lösche Eintrag

### Rezepte & Vorrät
- `GET /recipes` - Liste Rezepte auf
- `GET /ingredients` - Liste Zutaten auf
- `GET /units` - Liste Einheiten auf
- `GET /pantry` - Liste Bestandselemente auf
- `GET /storage-locations` - Liste Lagerorte auf
- `GET /shopping-list` - Liste Einkaufslistenelemente auf
- `GET /meal-plans` - Liste Essensplanungen auf

### Planner
- `GET /planner` - Termine (Top-Level inkl. verschachtelter Children)
- `POST /planner` - Einzeltermin erstellen (Start- & Endzeit)
- `PUT /planner/{id}` - Termin aktualisieren
- `DELETE /planner/{id}` - Termin löschen
- `POST /planner/recurring` - Wiederkehrende Serie anlegen
- `PUT /planner/{id}/recurring?scope=single|all|future` - Serientermin bearbeiten
- `DELETE /planner/{id}/recurring?scope=single|all|future` - Serientermin löschen
- `GET/POST/PUT/DELETE /planner/types` - Typen-Stammdaten verwalten
- `GET /planner/pending/notifications` - Fällige Benachrichtigungen (für n8n)

### Chat
- WebSocket-Verbindung für Echtzeit-Nachrichten
- `GET /messages` - Hole Nachrichtenhistorie

## 📖 Benutzerhandbuch

### Aufgabe erstellen
1. Navigiere zu **Tasks** in der Schublade
2. Klicke auf die **+**-Schaltfläche (FAB)
3. Fülle aus:
   - **Titel** (erforderlich)
   - **Beschreibung** (optional)
   - **Fälligkeitsdatum** (optional)
   - **Priorität** (Niedrig, Mittel, Hoch, Dringend)
   - **Kategorie** (optional)
   - **Zugewiesener Benutzer** (Standard: aktueller Benutzer)
4. Klicke **Erstellen** - die Aufgabe erscheint in "Zu tun"

### Aufgaben auf Kanban-Board verwalten
1. **Ansicht**: Alle Aufgaben in drei Spalten:
   - **Zu tun** - Neue, nicht gestartete Aufgaben
   - **In Bearbeitung** - Aktuelle Aufgaben
   - **Fertig** - Abgeschlossene Aufgaben

2. **Verschieben**: Ziehe Aufgaben zwischen Spalten
3. **Bearbeiten**: Klicke auf das Bearbeitungs-Symbol
4. **Benutzer ändern**: Klicke auf den Benutzer-Avatar
5. **Löschen**: Klicke auf das Lösch-Symbol (Papierkorb)

### Zeitverfolgung
1. Navigiere zu **Zeiten**
2. Erstelle einen neuen Zeiteintrag
3. **Eintrag beenden**: Klicke auf das blaue Häkchen-Symbol, um die Endzeit zu setzen
4. Sieh die automatisch berechnete Dauer
5. **Endzeit löschen**: Klicke auf das X neben der Endzeit

### Rezeptverwaltung
1. **Rezepte durchsuchen**: Im **Rezepte**-Bereich
2. **Rezept erstellen**: Neue Rezepte mit Zutaten
3. **Kategorien verwalten**: Im **Kategorien**-Management
4. **Zutaten verwalten**: Im **Zutaten**-Management
5. **Einheiten einstellen**: Im **Einheiten**-Management

### Vorrätsverwaltung & Einkaufen
1. **Bestandsverfolgung**: Im **Vorräte**-Bereich
2. **Elemente hinzufügen**: Mit Menge und Lagerlokation
3. **Schwellwerte einstellen**: Mindestmengen definieren
4. **Einkaufsliste erstellen**: Im **Einkaufsliste**-Bereich
5. **Essensplanung**: Im **Essensplaner** und Auto-Generierung von Einkaufslisten

### Chat
1. Navigiere zu **Chat**
2. Wähle einen Benutzer zum Chatten
3. Tippe und sende Nachrichten
4. Sieh Echtzeit-Updates

## 🎨 Design-Highlights

### Farbschema
- **Light Theme**: Saubere weiße Hintergründe mit blauer Primärfarbe
- **Dark Theme**: Dunkle Hintergründe (#1E1E2E) mit Material You Farben
- **Material Design 3**: Folgt neuesten Material Design Spezifikationen

### Responsive Layout
- Anpassungsfähige Schublade (285px Breite) mit glatten Animationen
- Responsive Gitter für Rezepte und Vorratselemente
- Optimierte Eingabeformulare für Mobilgeräte

### Benutzererlebnis
- Glatte Seiten-Übergänge mit Animationen
- Schublade Fade-In Animation beim Laden
- Visuelles Feedback für interaktive Elemente
- Klare Status-Indikatoren

### Dark Mode Unterstützung
- Vollständige Material You Theme-Unterstützung
- Automatische Theme-Umschaltung
- Anpassbar über Einstellungen

## 🔒 Sicherheitsaspekte

### Authentifizierung
- Benutzer-Anmeldedaten werden auf Backend validiert
- Session-Token werden von ApiClient verwaltet
- Automatischer Logout bei Authentifizierungsfehlern

### Datenschutz
- Alle API-Aufrufe verwenden sichere HTTP/HTTPS-Verbindungen
- Sensitive Daten in SharedPreferences
- Benutzer-Input wird vor der Übermittlung validiert

### Empfehlungen
- Verwende sichere Speicherung für Token (FlutterSecure)
- Implementiere Token-Refresh-Mechanismus
- Addiere Certificate Pinning für HTTPS
- Validiere alle Benutzer-Input auf Client und Server

## 💻 Entwicklungs-Workflow

### Neue Features hinzufügen
1. Datenmodell in `lib/dataclasses/` erstellen
2. Service in `lib/dataservice/` mit API-Aufrufen
3. Provider in `lib/provider/` für State Management
4. UI-Seite in `lib/tabs/` erstellen
5. Route zu `AppRoutes` in `main.dart` hinzufügen
6. Navigations-Element zur Schublade hinzufügen

### Code-Stil
- Folge Dart-Konventionen (camelCase, PascalCase)
- Verwende `const` Konstruktoren wo möglich
- Präferiere unveränderliche Datenmodelle mit `copyWith`
- Halte Widgets fokussiert und zusammensetzbar
- Verwende Provider für State Management

## 🐛 Fehlerbehebung

### API-Verbindungsprobleme
- Backend-Server läuft
- `api_client.dart` baseUrl korrekt
- Netzwerk-Verbindung aktiv
- Firewall/Proxy-Einstellungen prüfen

### Authentifizierungsprobleme
- SharedPreferences Cache leeren: `flutter clean`
- Mit korrekten Anmeldedaten erneut anmelden
- Backend-Auth-Endpoints prüfen

### Build-Probleme
- Führe `flutter clean` und `flutter pub get` aus
- Flutter-Version prüfen: `flutter --version`
- SDK-Constraints in pubspec.yaml prüfen

## 🔮 Zukünftige Verbesserungen

- [ ] Offline-Synchronisierung mit lokaler Datenbank
- [ ] Push-Benachrichtigungen für Aufgaben
- [ ] Task-Zusammenarbeit und Kommentare
- [ ] Erweiterte Rezept-Nährstoff-Verfolgung
- [ ] Budget-Verfolgung für Essensplanung
- [ ] Zeitverfolgung Analytics und Berichte
- [ ] Wiederkehrende Aufgaben und Gewohnheits-Verfolgung
- [ ] Backup und Export-Funktionalität

## 📝 Lizenz

Dieses Projekt ist Teil einer Schulaufgabe.

## 🤝 Beitragen

1. Feature-Branch erstellen (`git checkout -b feature/new-feature`)
2. Änderungen committen (`git commit -m 'Add new feature'`)
3. Zu Branch pushen (`git push origin feature/new-feature`)
4. Pull Request öffnen

## 📧 Unterstützung

Bei Problemen und Fragen:
1. Prüfe existierende Issues im Repository
2. Erstelle ein neues Issue mit detaillierter Beschreibung
3. Füge Error Logs und Schritte zum Reproduzieren bei

## 👤 Autor

Jan-Philip Anft

---

**Zuletzt aktualisiert**: Juni 2026

# Productivity App - Flutter

Eine umfassende Flutter-Anwendung für persönliche Produktivitätsmanagement mit Aufgabenverwaltung, einem Kalender-/Planner-Modul (inkl. wiederkehrender Termine), Rezepten, Vorratsverwaltung, Essensplanung, Zeitverfolgung, Notizen, Journal, Echtzeit-Chat und einem Haushaltsbuch — das Ganze wahlweise allein oder gemeinsam in einem Haushalt.

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

### 💶 Haushaltsbuch
- **Kassen**: „Bar", „Giro", „Sparen", „Kreditkarte" — je mit
  Anfangsbestand, Farbe und Mitgliedern. Ein überzogenes Konto fängt mit
  einem Minus an.
- **Eine Tabelle für beides**: Gehalt und Wocheneinkauf sind derselbe
  Vorgang mit anderem Vorzeichen. Im Dialog steht kein Minuszeichen,
  sondern ein Schalter **Ausgabe / Einnahme**.
- **Beträge in Cent**, nie als Fließkomma — über ein Jahr Summen driftet
  sonst der Saldo um Beträge, die man danach sucht.
- **Daueraufträge mit Betragsstaffel**: „Strom, monatlich am 1." trägt
  seinen Betrag *ab einem Stichtag*. Ändert sich der Abschlag, kommt eine
  neue Stufe dazu — die Vergangenheit bleibt stehen und stimmt weiter.
- **Die Zukunft wird gerechnet, nicht gebucht.** Bis heute stehen echte
  Buchungen, ab morgen eine Vorschau („Was noch kommt"), die bei jeder
  Abfrage neu entsteht. Sie ist blasser gezeichnet und nicht antippbar,
  weil es sie noch nicht gibt.
- **„am 31." heißt „am letzten"** — im Februar wird gekürzt statt
  übersprungen. Fällt eine Fälligkeit auf ein Wochenende, wird sie
  **nicht** verschoben; eine Bank tut das, wir nicht.
- **Auswertung** je Monat: Saldo, Einnahmen, Ausgaben und die Verteilung
  nach Kategorie — gerechnet im Backend, nicht im Client.
- **Vier Kacheln** fürs Dashboard: Saldo, Ausgaben nach Kategorie,
  Verlauf über N Monate, „Was noch kommt".
- **Aus dem Einkauf buchen**: Abgehakte Posten × Preisgedächtnis ergeben
  einen **Vorschlag**, keine Buchung. Der Betrag ist vorher änderbar, die
  Buchung trägt ihre Herkunft in der Notiz, und Posten ohne bekannten
  Preis werden genannt und gezählt statt stillschweigend weggelassen.
- **Jarvis kann buchen**: „Trag zwölf Euro Edeka ein" — mit Rückfrage,
  wenn es mehrere Kassen gibt, und wie immer erst nach Bestätigung.

### 🏠 Haushalte
- **Koexistenz, nicht Umbau**: Wer in keinem Haushalt ist, merkt vom
  ganzen Bereich nichts — kein Menüpunkt, keine Umschaltung, nichts
  fehlt. Die App verhält sich wie vorher.
- **Höchstens ein Haushalt je Person.** Das erspart der App einen
  Umschalter und jeder Abfrage einen Kontext.
- **Gemeinsam werden**: Rezepte, Vorrat, Einkaufslisten, Preise,
  Essensplan und Kassen. **Global bleiben** Einheiten, Zutaten,
  Kategorien und Läden — „Gramm" und „Mehl" sind Vokabular, kein Besitz.
- **„Meins / Unseres"** im Kopf jeder betroffenen Seite; sie entscheidet
  auch, wohin Neues gehört. Einzelnes lässt sich nachträglich verschieben.
- **Einladung als Ablauf**: annehmen, ablehnen, zurückziehen. Vor dem
  Annehmen sieht keine Seite etwas von der anderen.
- **Finanz-Sichtbarkeit entscheidet jedes Mitglied selbst** — vier Stufen
  von „nichts" bis „alles", Vorgabe ist **nichts**. Wer nicht mitrechnet,
  wird in der gemeinsamen Übersicht genannt: „2 von 3 Mitgliedern rechnen
  mit."
- **Der Besitzer kann nicht gehen**, solange andere drin sind — er
  übergibt erst. Geht der Letzte, löst sich der Haushalt auf und die Daten
  fallen an ihn zurück.

### ⚙️ Einstellungen
- **Serveradresse**: frei einstellbar, mit Erreichbarkeitsprüfung. Kein
  eigener Bauvorgang nötig, um die App gegen einen anderen Server zu
  betreiben. Ein Wechsel meldet ab – das Token gilt beim alten Server.
- **Design-Anpassung**: Wechsel zwischen Hell- und Dunkelmodus
- **Benutzereinstellungen**: Personalisiere App-Verhalten
- **Kontoeinstellungen**: Verwalte Benutzerprofilinformationen

### 📊 Dashboard (frei zusammenstellbar)
- **Zwei Übersichtsseiten** (Home und Dashboard), Anordnung pro Konto im
  Backend gespeichert – gilt auf allen Geräten.
- **Dreistufiger Rückfall**: Backend (3 s Zeitlimit) → lokaler Cache →
  Standard aus dem Code. Ist der Server weg, steht trotzdem etwas da.
- **Kacheln per Drag & Drop** umsortieren, ein- und ausblenden;
  Abschnitte auf- und zuklappen.
- **Eigene Kacheln** aus Quelle × Darstellung × Filter: zehn Quellen, drei
  Darstellungen (große Zahl, Liste, Balken). Welche Darstellung zu welcher
  Quelle passt, ergibt sich aus deren Form.
- **Filter nach Datentyp**: Feld → Operator (bei Zahlen `> < =`, bei Text
  „enthält", bei Datum „in den letzten … Tagen") → Wert per Freitext,
  Datumswähler oder Auswahlliste. Mehrere Bedingungen als UND.
- Antippen öffnet die passende Seite.

### 🛡️ Rechte in der Oberfläche
- Das Menü zeigt nur, was der angemeldete Nutzer benutzen darf; ein leerer
  Abschnitt verschwindet samt Überschrift.
- Die Übersichtsseiten laden **jede Quelle einzeln**. Ein fehlendes Recht
  lässt eine Kachel weg, statt die Seite abzureißen.
- Wer angemeldet, aber noch nicht freigeschaltet ist, bekommt eine
  Erklärung statt einer leeren App.
- Das ist **Höflichkeit, keine Absicherung** – geprüft wird an jedem
  Endpunkt im Backend.

### 👥 Verwaltung (nur mit Verwaltungsrecht)
- **Benutzer** mit Online-Punkt, „zuletzt gesehen" und Rollen; anlegen,
  Rollen setzen, Passwort zurücksetzen, deaktivieren, löschen.
- **Rollen** zusammenstellen: Rechte nach Bereich gruppiert. „Ändern"
  setzt „Sehen" mit, „Sehen" wegnehmen nimmt „Ändern" mit.
- **Standardrolle** festlegen: was ein neu angelegter Nutzer bekommt.
- Der Löschdialog zeigt vorher, was verloren geht.

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
│   ├── api_client.dart               # Dio HTTP-Client, Basis-Adresse
│   ├── server_config.dart            # Serveradresse: speichern, prüfen
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
│   ├── finanzen/                     # Haushaltsbuch
│   │   ├── finanzen_page.dart        # Monatsansicht mit Vorschau
│   │   ├── buchung_dialog.dart       # Ausgabe/Einnahme erfassen
│   │   ├── serien_page.dart          # Daueraufträge
│   │   ├── serie_dialog.dart         # Regel anlegen/ändern
│   │   ├── stufe_dialog.dart         # Stufe der Betragsstaffel
│   │   └── kassen_page.dart          # Kassen und Mitlesende
│   ├── haushalt/                     # Haushalt, Einladungen, Finanzsicht
│   ├── einkauf/                      # Einkaufslisten und Preise
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

## 📱 Aufs eigene iPhone bringen

```bash
./deploy/aufs-handy.sh
```

iPhone anschließen, entsperren, Kommando ausführen — es baut, signiert,
installiert und startet. Ein Lauf, keine Handgriffe dazwischen.

Hängt mehr als ein Gerät dran, fragt es:

```
  Mehrere Geraete. Wohin soll die App?
  1) iPhone von Malin         iPhone14,8   am Kabel
  2) IPhone von JP (2)        iPhone15,4   im WLAN

  Nummer [1]:
```

Am Kabel angeschlossene stehen oben und sind die Vorgabe — ein Telefon,
das nur im WLAN sichtbar ist, steht meist bloß herum. `--geraet "Malin"`
überspringt die Frage (Name, Modell oder Kennung), `--liste` zeigt nur,
was da ist, `--ziehen` holt vorher den neuesten Stand.

**Ein neues Telefon braucht keine Sonderbehandlung.** Das
Bereitstellungsprofil gilt je Gerät, und `flutter build ios` baut für ein
*generisches* — es fragt deshalb nie nach einem Profil für genau dieses
Telefon, und das Installieren scheitert dann mit `0xe8008012`. Das Skript
baut über `flutter run`, weil das die Gerätekennung an Xcode durchreicht
und das Profil erneuern lässt. Einmal am Gerät nötig ist nur der
**Entwicklermodus** (Einstellungen → Datenschutz & Sicherheit) und beim
ersten Start das Vertrauen zum Zertifikat (Einstellungen → Allgemein →
VPN & Geräteverwaltung); nach beidem sagt das Skript, wenn es fehlt.

**Warum das wöchentlich nötig ist:** Das Entwicklerkonto ist ein
kostenloses. Apple gibt dafür Bereitstellungsprofile mit **sieben Tagen**
Laufzeit — danach startet die App nicht mehr, ohne dass sich am Programm
etwas geändert hätte. Ein bezahltes Konto (99 €/Jahr) macht daraus ein
Jahr; solange es das nicht gibt, ist dieses Kommando die Wöchentlichkeit.

**Warum kein Server-Job:** Zum Signieren braucht Xcode das angeschlossene
Gerät, weil dessen Kennung im Profil steht. Ein Job, der es allein
versucht, scheitert in sechs von sieben Fällen. Der Mac kann nur daran
erinnern:

```bash
./deploy/woechentliche-erinnerung.sh ein
```

Meldet sich sonntags um 18 Uhr. `aus` entfernt sie wieder.

Der Weg über AltStore/SideStore (Workflow *iOS-ipa-build*) bleibt daneben
bestehen — dort signiert das Telefon selbst, dafür muss man die App über
AltStore aktualisieren statt über das Kabel.

## 🤖 Aufs Android-Tablet bringen

```bash
./deploy/aufs-tablet.sh              # per Kabel
./deploy/aufs-tablet.sh --anbieten   # ohne Kabel, ohne Entwickleroptionen
./deploy/aufs-tablet.sh --funk 192.168.1.42:5555   # drahtlos per adb
```

Drei Wege, weil ein Tablet an der Küchenwand selten am Kabel hängt:

| Weg | Voraussetzung |
|---|---|
| **Kabel** | Entwickleroptionen → USB-Debugging |
| **Funk** | Android 11+, einmal `adb pair` |
| **Anbieten** | nichts — das Tablet lädt die Datei im Browser |

`--anbieten` baut und stellt die APK im WLAN bereit; auf dem Tablet die
angezeigte Adresse öffnen, herunterladen, antippen. Die Installation aus
unbekannter Quelle muss einmal erlaubt werden.

**Zur Signierung:** Die Freigabe-APK wird derzeit mit dem *Debug*-Schlüssel
signiert (`android/app/build.gradle.kts`). Für den Eigengebrauch reicht
das, hat aber zwei Folgen: Der Schlüssel hängt an diesem Mac, und ein
späterer Wechsel auf einen echten Schlüssel verlangt einmal
Deinstallieren.

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

3. **API-Verbindung konfigurieren** – *nicht mehr im Code*

   Die Serveradresse wird **in der App** eingestellt: unten am
   Login-Bildschirm oder in den Einstellungen ganz oben. Es genügt der
   Rechnername (`meinserver.de`) – `https://` wird ergänzt, `/api`
   angehängt, und was daraus wird, steht vor dem Speichern da.

   Vor dem Übernehmen prüft die App, ob dort wirklich diese API antwortet.
   Eine falsche Adresse fiele sonst erst beim Anmelden auf und sähe aus wie
   ein falsches Passwort.

   Optional lässt sich beim Bauen eine **Vorgabe** mitgeben, die ohne
   Einstellung gilt:
   ```bash
   flutter build web --release --dart-define=API_URL=https://api.example.de/api
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

### Finanzen
- `GET /finanzen/kassen?alle=` - Kassen (mit `alle` für `finance:read_all`)
- `POST/PUT/DELETE /finanzen/kassen[/{id}]` - Kassen pflegen
- `POST/DELETE /finanzen/kassen/{id}/mitglieder/{uid}` - Mitlesende
- `GET/POST/PUT/DELETE /finanzen/kategorien[/{id}]` - eigene Kategorien
- `GET /finanzen/buchungen?kasse=&von=&bis=` - Buchungen im Zeitraum
- `POST/PUT/DELETE /finanzen/buchungen[/{id}]` - Buchungen pflegen
- `GET/POST/PUT/DELETE /finanzen/serien[/{id}]` - Daueraufträge
- `POST /finanzen/serien/{id}/betrag` - Stufe der Betragsstaffel setzen
- `DELETE /finanzen/serien/{id}/betrag/{bid}` - Stufe entfernen
- `GET /finanzen/vorschau?von=&bis=` - was kommt (ohne `id`, nie gespeichert)
- `GET /finanzen/auswertung?von=&bis=` - Saldo, Summen, Verteilung
- `POST /finanzen/nachbuchen` - fällige Serienbuchungen nachtragen
- `GET /einkauf/{id}/buchungsvorschlag?shop_id=` - Schätzung aus dem
  Preisgedächtnis (`shopping:read` **und** `prices:read`)

### Haushalt
- `GET /haushalt` - Der eigene Haushalt (204, wenn man in keinem ist)
- `POST/PUT/DELETE /haushalt` - Anlegen, ändern, auflösen
- `GET /haushalt/einladungen` - Offene Einladungen an mich
- `POST /haushalt/einladungen` - Jemanden einladen
- `POST /haushalt/einladungen/{id}/annehmen|ablehnen` - Antworten
- `PUT /haushalt/finanz-sicht` - Die eigene Sichtbarkeitsstufe
- `DELETE /haushalt/mitglieder/me` - Austreten
- `POST /haushalt/besitz/{uid}` - Haushalt übergeben
- `GET /haushalt/finanzen?von=&bis=` - Zusammengerechnet über alle
  Mitglieder, so weit wie jedes es erlaubt

Dazu an den haushaltsfähigen Bereichen: `?unseres=` und `?eigene=` zum
Filtern, `PUT .../haushalt` zum Verschieben.

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
- Serveradresse stimmt (Login-Bildschirm → unten, oder Einstellungen → Server).
  Die App prüft die Erreichbarkeit dort selbst.
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

### Bewusst nicht gebaut

Das ist keine Liste von Lücken, sondern von Entscheidungen. Sie stand in
den Bauplänen von Haushaltsbuch und Haushalten; die Pläne sind mit dem
Bau erledigt, die Begründungen gelten weiter.

| | Warum nicht |
|---|---|
| **Bankanbindung** | Eigenes Vorhaben mit eigenen Fallstricken (Zustimmungsfristen, Kategorisierung, Abgleich). `finance_accounts` und `external_uid` halten ihr die Tür auf, mehr bewusst nicht. |
| **Budgets und Sparziele** | Erst wissen, wofür man Geld ausgibt, dann Grenzen ziehen. Sonst setzt man sie ins Blaue. |
| **Eine Buchung auf mehrere Kategorien aufteilen** | Kommt vor (Lebensmittel *und* Drogerie), ist aber eine eigene Tabelle samt Oberfläche. |
| **Belegfotos** | Braucht eine Dateiablage, die es im Backend nicht gibt. |
| **Bon-Scan → Buchung** | Der Bon liefert den *echten* Betrag statt einer Schätzung — die Stufe nach der Einkaufs-Brücke, und erst, wenn die sich bewährt hat. |
| **Mehrere Währungen** | Nein. |
| **Mehrere Haushalte je Person** | Bräuchte einen Umschalter und in jeder Abfrage einen Kontext. Das Datenmodell lässt es offen: die Mitgliedschaft steht in einer eigenen Tabelle, nicht als Feld am Nutzer. |
| **Rollen im Haushalt jenseits von Besitzer/Mitglied** | „Kind darf keine Finanzen sehen" geht über eine App-Rolle, nicht über den Haushalt. |
| **Haushalte über Server hinweg** | Nein. |
| **Einladung per Link an Fremde** | Eingeladen wird, wer schon ein Konto hat. Registrierung ist ein anderer Vorgang. |
| **Serienbuchung als Fälligkeits-Erinnerung** | Die Mitteilungen sind auf 58 vorgemerkte gedeckelt (iOS-Grenze 64). Eine neue Quelle müsste durch `NotificationScheduler.rescheduleAll()` gehen, sonst kennt sie das Budget der anderen nicht. |

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

**Zuletzt aktualisiert**: September 2026

## Zugehöriges Backend

Die API liegt im Schwesterprojekt
[OwnAPI](https://github.com/StaysIsTaken/OwnAPI). Aufsetzen dort ist ein
Befehl (`./deploy/setup.sh prod`); Datenbank, Schema und Grundrollen
entstehen dabei von selbst, und wer sich als Erster registriert, bekommt
die Verwaltung.

## Tests

```bash
flutter test
flutter analyze
```

**736 Tests.** Neben Einheitentests auch Widget-Tests für das Menü: der
Drawer wird mit einem eingeschränkten Rechtestand aufgebaut, und der Test
sieht nach, was wirklich dasteht — inzwischen auch, ob der
Haushaltsabschnitt verschwindet, wenn es keinen Haushalt gibt.


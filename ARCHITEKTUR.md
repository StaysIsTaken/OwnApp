# ARCHITEKTUR.md — OwnApp

Was die Kommentare im Code nicht tragen können.

Die Kommentare in diesem Projekt erklären ihre Stelle gut — meist steht
dabei, *warum* etwas so ist und nicht nur *was* es tut. Was sie
naturgemäß nicht können: sagen, dass es an einer **anderen** Stelle etwas
Ähnliches gibt und welches von beidem gilt.

Genau daran verliert man hier Zeit. Diese Datei ist die Liste der
Doppelgänger.

Gegenstück: `ARCHITEKTUR.md` in **OwnAPI**. Die Einkaufs-Spaltung zieht
sich durch beide Projekte, und wer nur eine Hälfte liest, zieht den
falschen Schluss.

---

## 1. Es gibt zwei Einkaufsmodelle. Das neue gewinnt.

Das ist die wichtigste Zeile dieser Datei.

| | alt | neu |
|---|---|---|
| Datenklasse | `ShoppingListItem` | `Einkaufsliste` + `Einkaufsposition` |
| Dienst | `ShoppingListService` | `EinkaufService` |
| Seite | `tabs/pantry/shopping_list_page.dart` | `tabs/einkauf/einkaufslisten_page.dart` |
| Route | `AppRoutes.shoppingList` | `AppRoutes.einkauf` |
| Zettel | genau einer, flach | beliebig viele |
| Position | braucht eine Zutat | ein Name genügt |
| Preise | hängen am Posten | hängen an der **Bezeichnung** |

Der letzte Punkt war der Anlass für den Neubau: im alten Modell
verschwand das Preiswissen mit dem Posten, den man abhakte.

### Der Stand nach der Umstellung

Die **Seite** ist weg, und mit ihr Route, Drawer-Eintrag und die
Kachelquelle `shopping.open` (ein reines Duplikat von `einkauf.liste`).
Der Kreislauf läuft jetzt auf den neuen Listen:

* **Essensplan → Einkauf:** `meal_plan_page.dart` fragt, auf welchen
  Zettel, überspringt was dort schon steht, und legt Positionen **mit
  Zutat** an. Ohne die Zutat liesse sich der Posten später nicht in den
  Vorrat zurückbuchen.
* **Einkauf → Vorrat:** `EinkaufService.inDenVorrat()`, erreichbar über
  das Küchen-Symbol in `einkaufsliste_page.dart`. Positionen ohne Zutat
  kommen als `ohneZutat` zurück und werden gemeldet, statt still
  liegenzubleiben.

### Das alte Modell ist weg

In der App restlos: `ShoppingListService`, `ShoppingListItem`,
`ShoppingListItemPrice(Service)` und `FilterFields.einkauf` sind
gelöscht, `DashboardData.shoppingItems` ebenso. Der Dashboard-Block, die
Einkaufs-Sektion auf der Startseite und der Lader der Küchenansicht
laufen auf `EinkaufService`.

Der „günstigste Laden" im Dashboard-Block steht damit auf besserer
Grundlage: vorher rechnete er über `ShoppingListItemPrice` — Preise, die
am Posten hingen und mit ihm verschwanden. Jetzt kommt er aus
[Preisvergleich] und damit aus dem Preisgedächtnis, das an der Ware
hängt.

**Im Backend lebt das alte Modell weiter**, und zwar mit gutem Grund:
`receipt.py` (Bon-Scan) schreibt dorthin. Die App zielt beim Bon-Scan
allerdings nur auf den Vorrat (`target: 'pantry'`) — der
Einkaufs-Zweig ist von hier aus nicht mehr erreichbar.

### Eine Falle, die den Modellwechsel überlebt hat

Ein leerer String ist keine Kennung. Beim alten Modell ging eine leere
`unitId` als `''` mit, der Fremdschlüssel lehnte sie ab, der Server
stürzte ab — und weil ein abgestürzter Server keine CORS-Kopfzeilen mehr
setzt, meldete der Browser einen CORS-Fehler statt des echten Grundes.

Darts `?wert` lässt nur null weg, nicht den leeren String. Deshalb gibt
es `EinkaufService.kennung()`, und deshalb wird sie geprüft.

---

## 2. Benachrichtigungen: geplant auf dem Gerät, nicht gepusht

| Weg | Wofür | Bei geschlossener App? | Web? |
|---|---|---|---|
| **Lokal geplant** (`NotificationScheduler`) | Termine, Aufgaben | **ja** | nein |
| **WebSocket** (`NotificationService`) | Chat, ablaufender Vorrat, `planner_changed` | nein | nur bei offener Seite |

Ein dritter Weg (n8n → ntfy, nur für die Journal-Erinnerung) ist
**entfernt**. Der ntfy-Server läuft nicht mehr.

### Warum nicht Push

Remote-Push auf iOS braucht das `aps-environment`-Entitlement, und das
gibt es nur mit einer bezahlten Apple-Developer-Mitgliedschaft
(99 €/Jahr) — auch über Firebase nicht, das leitet nur an APNs weiter.
Lokale geplante Mitteilungen brauchen es nicht.

Dazu kommt ein Argument, das unabhängig vom Geld gilt: eine
Push-Erinnerung entsteht auf dem Server. Termine hingen damit an einem
laufenden, erreichbaren `ownserver`. Heute hängen sie an nichts davon —
das Betriebssystem klingelt ohne Netz, ohne Server, ohne Verzögerung.

Push bleibt die richtige Technik dort, wo der Zeitpunkt **beim Anlegen
nicht feststeht**: Chat, geteilte Termine von Fremden, ablaufender
Vorrat. Genau das macht der WebSocket, solange die App offen ist.

### Vier Auslöser halten den Vorrat aktuell

Alle gehen durch `ErinnerungsAbgleich.jetzt()`:

| Auslöser | erzwingt? |
|---|---|
| App-Start | ja |
| Rückkehr in den Vordergrund | nein (Ruhezeit 2 min) |
| `planner_changed` über WebSocket | ja |
| Hintergrundlauf (6 h, Workmanager) | ja |

Vorher gab es **nur den letzten**. Auf Android reicht das; auf iOS ist
der Hintergrundlauf eine Bitte und kein Versprechen — er kann tagelang
ausbleiben. Ein Termin, den das Tablet angelegt hatte, rutschte auf dem
iPhone unbemerkt durch.

`planner_changed` kommt aus `planner_broadcast.py` (OwnAPI) und trägt
**bewusst keinen Inhalt**: ein privater Termin stünde sonst im Klartext
im WebSocket, und eine inhaltslose Meldung kann nicht veralten.

### Das iOS-Limit ist der Grund für den ganzen Aufbau

iOS merkt sich **höchstens 64 vorgemerkte Mitteilungen pro App**. Alles
darüber wird stillschweigend verworfen — kein Fehler, kein Log.

Deshalb planen Aufgaben und Termine **nicht** je für sich ein.
`TaskNotificationScheduler.plan()` und
`PlannerNotificationScheduler.plan()` geben nur `PlannedNotification`s
*zurück*; erst `NotificationScheduler.rescheduleAll()` sortiert alles
gemeinsam nach Zeit und kürzt auf `maxPending = 58`. Wer eine neue
Erinnerungsquelle baut, muss denselben Weg nehmen — sonst kennt sie das
Budget der anderen nicht.

Die ID-Räume sind aus demselben Grund getrennt und dürfen sich nicht
überschneiden:

```
3.000.000  Aufgaben, Tag der Fälligkeit
4.000.000  Aufgaben, Tag davor
5.000.000  Termine
```

`_cancelManaged()` räumt nur innerhalb dieser Räume ab — sonst löschte ein
Neuplanen die bereits sichtbaren Chat-Hinweise mit.

### Web hat gar nichts

Jeder Pfad bricht bei `kIsWeb` ab. Das ist kein Versehen: **geplante**
Mitteilungen kann ein Browser grundsätzlich nicht selbst — es gibt keine
Möglichkeit, im Voraus etwas zu hinterlegen. Wer sie dort will, braucht
Web-Push (Service Worker, VAPID, Abo-Tabelle) **und** einen Server, der
zum richtigen Zeitpunkt sendet. Das ist eine andere Architektur als auf
dem Telefon, nicht dieselbe mit einem Häkchen mehr.

---

## 3. Die Sprachsteuerung hat eine Reihenfolge, und die ist Absicht

`SprachProvider._verarbeite()` arbeitet von oben nach unten. Jede Stufe,
die greift, beendet den Ablauf:

```
1. Kalenderauswahl    „zeige nur den Arbeitskalender an"
2. Navigation         „geh zum Kalender"
3. Timer              „stell einen Timer für fünf Minuten"
4. Auskunft           Uhrzeit, Datum, Wetter
5. das Sprachmodell   alles Übrige
```

**Warum nicht alles ans Modell?** Zwei Gründe, und beide stehen auch im
Code: der Umweg kostet Sekunden, und das Modell kennt weder die Seiten
dieses Geräts noch seinen Timer. Die Uhrzeit rät es sogar — aus
Trainingsdaten, oft um Stunden daneben, ohne es zu merken.

**Warum die Kalenderauswahl ganz oben steht:** sie fängt mit demselben
Wort an wie ein Seitenwechsel. „Zeige nur den Arbeitskalender an" wäre
sonst die Suche nach einer Seite dieses Namens.

Wer eine Stufe hinzufügt, muss sie eng fassen. Ein gieriger Parser fängt
Sätze ab, die ans Modell gehört hätten — deshalb verlangt der
Timer-Parser das Wort „Timer" und die Navigation ein einleitendes Verb.

---

## 4. Zustand, der aus einem Widget heraus musste

Zweimal dasselbe Muster, und es wird ein drittes Mal auftreten:

* `TabletSeitenProvider` — die Seiten der Küchenansicht.
* `TimerProvider` — die Eieruhr.

Beide lagen als privater State im Widget. Beide mussten heraus, sobald
die **Sprachsteuerung** sie von aussen stellen sollte: an privaten
Widget-State kommt sie nicht heran.

Merkmal zum Wiedererkennen: sobald etwas per Zuruf bedienbar werden soll
oder weiterlaufen muss, während man woanders hinsieht, gehört es in einen
Provider.

Der `TimerProvider` zählt **pro Takt herunter**, statt gegen einen
Zielzeitpunkt zu rechnen. Das ist bewusst — und es ist zugleich seine
Grenze: legt das Betriebssystem die App schlafen, steht der Timer und
läuft danach nach. Für ein Küchentablet mit Wakelock stimmt das, für ein
Telefon in der Hosentasche nicht.

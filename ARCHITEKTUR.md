# ARCHITEKTUR.md — OwnApp

Was die Kommentare im Code nicht tragen können.

Die Kommentare in diesem Projekt erklären ihre Stelle gut — meist steht
dabei, *warum* etwas so ist und nicht nur *was* es tut. Was sie
naturgemäß nicht können: sagen, dass es an einer **anderen** Stelle etwas
Ähnliches gibt und welches von beidem gilt.

Genau daran verliert man hier Zeit. Diese Datei ist die Liste der
Doppelgänger.

Gegenstück: `ARCHITEKTUR.md` in **OwnAPI**. Die Regeln, wem etwas gehört,
ziehen sich durch beide Projekte, und wer nur eine Hälfte liest, zieht den
falschen Schluss.

---

## 1. Es gab zwei Einkaufsmodelle. Das alte ist weg.

Lange stand hier „das neue gewinnt" — inzwischen ist die linke Spalte
restlos verschwunden, in **beiden** Repos. Sie steht noch da, weil man
ihren Namen in Kommentaren, Migrationen und Commit-Texten findet und dann
wissen will, was gemeint war.

| | alt — **weg** | neu — **gilt** |
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

**Im Backend ebenfalls.** Das stand hier lange andersherum — „dort lebt
es weiter, weil `receipt.py` hineinschreibt". Inzwischen liegt auch der
Bon-Scan auf den neuen Listen, und Migration `028` hat die beiden
Tabellen gelöscht. Es gibt das alte Modell nirgends mehr.

Die App zielt beim Bon-Scan trotzdem nur auf den Vorrat
(`target: 'pantry'` in `pantry_page.dart`). Das ist jetzt eine freie
Entscheidung der Oberfläche und keine Einschränkung des Backends: der
Zweig `target: 'shopping'` ist da, gepflegt und legt Positionen auf einem
Zettel an, den der Nutzer vorher wählt. Wer ihn in der App anbieten will,
braucht dafür nichts Neues im Backend.

### Wie Zettel, Zutat, Preis und Laden zusammenhängen

Die vier Teile sind schnell erklärt. Interessant ist, **wie** sie
verbunden sind — denn genau dort steckt die Entwurfsentscheidung.

```
                   ┌──────────────────┐
                   │  Einkaufsliste   │   „Wocheneinkauf"
                   │  ShoppingList    │
                   └────────┬─────────┘
                            │ 1:n
                   ┌────────▼─────────┐
                   │     Position     │   name          „Milch"   ← immer da
                   │ ShoppingPosition │   ingredient_id  optional
                   └───┬──────────┬───┘   amount, is_done
                       │          │
        über den NAME  │          │  über die ZUTAT
      (immer möglich)  │          │  (nur wenn gesetzt)
                       │          │
              ┌────────▼─────┐  ┌─▼────────────┐
              │    Preis     │  │    Vorrat    │
              │ ArticlePrice │  │  PantryItem  │
              └──────┬───────┘  └──────────────┘
                     │ shop_id
              ┌──────▼───────┐
              │    Laden     │   „Aldi"
              │     Shop     │
              └──────────────┘
```

**Der Punkt: zwischen Position und Preis gibt es keinen Fremdschlüssel.**

Verbunden sind sie über die **normalisierte Bezeichnung** —
`sls.normalisiere()` macht aus „ Milch" und „MILCH" dasselbe `milch`.
`ArticlePrice.bezeichnung` trägt diesen Schlüssel, `ShoppingPosition.name`
wird beim Nachschlagen genauso eingeebnet.

Das ist Absicht und der Grund für den ganzen Neubau. Im alten Modell hing
der Preis am Listeneintrag (`ShoppingListItemPrice` → `ShoppingListItem`).
Hakte man den Posten ab und räumte ihn weg, war das Preiswissen mit ihm
verschwunden. Über den Namen überlebt es jeden Einkauf — und gilt auch
für eine Ware, die zum ersten Mal auf diesem Zettel steht.

**Die Zutat ist die zweite, unabhängige Verbindung.** Sie zeigt zum
Vorrat, nicht zum Preis. Eine Position *kann* eine haben, muss aber
nicht:

| Position | Zutat? | Preis abfragbar? | In den Vorrat buchbar? |
|---|---|---|---|
| „Milch" (vom Essensplan) | ja | ja | ja |
| „Milch" (von Hand getippt) | nein | **ja** | nein |
| „Batterien" | nein | ja | nein |

Deshalb meldet `in_den_vorrat` die Posten ohne Zutat zurück, statt sie
still liegenzulassen — ein Vorrat führt Zutaten, keine freien Namen.

**Wo die Verbindungen tatsächlich hergestellt werden:**

| Stelle | Was sie tut |
|---|---|
| Tippen in der Liste | `EinkaufService.preise(name)` → zeigt, was bekannt ist |
| `Preisvergleich` | offene Positionen × bekannte Preise → Summe je Laden |
| `remember_price` (Jarvis) | schreibt `ArticlePrice` für (Name, Laden) |
| `aus_essensplan` | setzt die **Zutat**, damit der Rückweg offensteht |
| `in_den_vorrat` | folgt der Zutat, nicht dem Namen |

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

## 2b. Zwei Wochenansichten, ein gemeinsamer Unterbau

Es gibt sie zweimal, und das bleibt so:

| | `tile_week_view.dart` (Kachel) | `views/week_view.dart` (Planner) |
|---|---|---|
| Stundenfenster | aus den Terminen abgeleitet, 0–24 nur bei viel Platz | immer 0–24 |
| Stundenhöhe | passt sich dem Platz an | fest, 64 px |
| Termine platzieren | absolut in einem `Stack` | je Tag eine Spalte, Überlappung in Nebenspalten |
| Bedienung | zeigt nur | ziehen, antippen, Dialoge |

**Warum nicht eins daraus?** Ein Widget, das beides könnte, müsste
Stundenfenster, Stundenhöhe, zwei Platzierungsverfahren und die
Bedienbarkeit als Schalter tragen — und wäre schwerer zu lesen als die
zwei Dateien zusammen. Die Kachel hat ihre Rechnung nicht aus Versehen:
in einer Kachel verschenkt ein leerer Vormittag die halbe Fläche.

Gemeinsam ist deshalb nur, was **wirklich** dasselbe ist —
`widgets/kalender/wochenraster_teile.dart`:

* `zielStunde` / `startVersatz` — wo die Ansicht aufgeht. `abStunde`
  trägt das Stundenfenster der Kachel mit.
* `Ganztagsstreifen` + `Ganztagseintrag` — der Streifen über dem Raster.

Die Kachel hat durch die Auslagerung zwei Fehler verloren, die sie vorher
allein hatte: sie zeigte nur den **ersten** Ganztagstermin eines Tages
(Feiertag *und* Schulferien fallen regelmäßig zusammen) und mehrtägige
nur am **Anfangstag** (Ferien waren am Montag zu sehen und danach nie
wieder).

### Ganztägig ist abgeleitet, nicht gespeichert

`PlannerEntry.istGanztaegig` prüft **00:00 bis 23:59** — genau die Form,
die der ICS-Import schreibt (`_event_times`, das sein eigenes
`is_all_day` danach wegwirft). So kommen Müllabfuhr, Feiertage und
Schulferien herein.

Was die Regel nicht erfasst: einen von Hand als ganztägig *gemeinten*
Termin. Dafür bräuchte es ein echtes Feld im Backend.

### Ein Termin ohne Kalender ist sichtbar, bis jemand filtert

`PlannerProvider.sichtbar` lässt einen Termin mit `calendarId == null`
durch, solange kein Kalenderfilter gesetzt ist, und wirft ihn weg, sobald
einer gesetzt ist. Beides ist richtig — „nur der Arbeitskalender" heißt
nur der Arbeitskalender.

**Zusammen ergibt das aber den unangenehmsten Fehler, den es gibt: einen,
der wie Erfolg aussieht.** Ein Import, der den Kalender verlor, meldete
„300 neu", zeigte 300 Termine und ließ sie beim ersten Klick auf einen
Kalender wieder verschwinden. Mit einem Kalender merkt das niemand;
einen Haushaltskalender hat dagegen niemand allein.

Die Ursache lag im Backend und ist dort behoben (OwnAPI, §5 — „Was die
Vorlage nicht trägt, tragen die Vorkommen nicht"). Hier bleibt die
Lehre für die Oberfläche: wer eine Liste nach Kalendern filtert, soll
sich nicht darauf verlassen, dass jeder Termin einen hat — und wer einen
Zähler anzeigt, zählt damit womöglich etwas anderes als die Liste
darunter.

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

---

## 5. Es gibt drei Arten, wie etwas geteilt wird

Seit den Haushalten, und der nächste Leser muss wissen, welche wo gilt.
**Das ist der Doppelgänger, an dem man hier am ehesten die falsche
Annahme trifft** — „ich habe es doch freigegeben" heißt je nach Bereich
etwas anderes.

| Art | Bereiche | Wer sieht es |
|---|---|---|
| **Haushalt** | Rezepte, Vorrat, Einkaufslisten, Preise, Essensplan, Kassen, **Kalender** | alle Mitglieder |
| **Einzelfreigabe** | Listen, Kalender, Kassen | wer eingetragen ist |
| **Global** | Einheiten, Zutaten, Kategorien, Läden | jeder mit dem Recht |

Die mittlere Art ist mit den Haushalten **nicht** verschwunden. Sie löst
einen Fall, den der Haushalt nicht abdeckt: „diese eine Liste nur mit
meiner Schwester".

Der **Kalender steht in zwei Zeilen**, und das ist kein Versehen — siehe
§5b. Er ist der einzige Gegenstand, bei dem beide Arten nebeneinander
gelten und verschiedene Dinge bedeuten.

Und der Satz, der das Ganze trägt und den man sonst nicht rekonstruieren
kann:

> **Haushalte sind additiv. Wer keinen hat, verliert nichts.**

Daraus folgt alles Weitere — dass `household_id` überall NULL-bar ist,
dass `GET /haushalt` mit 204 antwortet statt mit einem Fehler, und dass
die Umschaltung „Meins / Unseres" samt ihrem Platz verschwindet, wenn man
in keinem Haushalt ist.

### Wo die Regel steht, und wo nicht

In der App an **einer** Stelle: `lib/dataservice/haushalt_sicht.dart`.
Dort ist sie eine reine Rechnung und damit prüfbar — derselbe Kunstgriff
wie bei `finanz_rechnung.dart`, und aus demselben Grund: die Seiten laden
beim Aufbau und lassen sich nicht testen, die Regel dahinter schon.

```dart
Haushaltssicht.zeigtMenue(...)       // gibt es den Menüabschnitt?
Haushaltssicht.zeigtUmschaltung(...) // gibt es „Meins / Unseres"?
Haushaltssicht.darfGehen(...)        // darf ich austreten?
Haushaltssicht.mitrechnenSatz(...)   // „2 von 3 rechnen mit"
```

Wer eine vierte Seite haushaltsfähig macht, ruft diese Funktionen auf,
statt `haushalt != null` ein viertes Mal zu schreiben. Beim vierten Mal
schreibt es sonst jemand anders.

### Der Haushalt liegt in einem Provider

`HaushaltProvider`, geladen im `AuthWrapper` zusammen mit den Rechten.
Das ist dasselbe Muster wie bei `TimerProvider` und
`TabletSeitenProvider` (§4): er musste aus der Seite heraus, weil das
**Menü** ihn braucht — und an privaten Zustand einer Seite kommt es nicht
heran.

Nebeneffekt, und er war beabsichtigt: so kommt auch eine **offene
Einladung** beim nächsten Öffnen der App an, ohne dass es dafür einen
WebSocket-Anstoß wie `planner_changed` braucht. Eine Einladung eilt
selten so, dass sich ein zweiter Zustellweg lohnt.

### Zwei Wege zur Haushaltsseite, und das ist Absicht

Im **Menü** steht sie nur, wenn es einen Haushalt gibt oder eine
Einladung offen ist. In den **Einstellungen** steht sie immer.

Ohne den zweiten Weg käme niemand je zu seinem ersten Haushalt — der
Menüpunkt erscheint ja erst, wenn es einen gibt. Die Einstellungen sind
der Ort, an dem man einrichtet, was einen selbst betrifft; dieselbe
Überlegung wie bei der Serveradresse, die am Login hängt und trotzdem
dort steht.

---

## 5b. Der Kalender wird zweimal geteilt, und die Oberfläche muss beides zeigen

Die zwei Sätze, die sich gleich anfühlen und verschieden sind:

| | „mein Kalender, aber ihr dürft mitlesen" | „unser Kalender" |
|---|---|---|
| Datenklasse | `Kalender.haushaltsFreigabe` | `Kalender.istHaushaltskalender` |
| `ownerId` | ich | **`null`** |
| `ownerName` | die Person | der **Haushalt** |
| Wo gestellt | Haushaltsseite, Schalter je Kalender | Haushaltsseite, „Anlegen" |
| Hineinschreiben | nur ich | jedes Mitglied |
| Löschen | ich | wer den Haushalt führt |

**`ownerId == meineId` ist seitdem die falsche Frage.** Beim gemeinsamen
Kalender steht dort niemand — eine Seite, die so rechnet, zeigt ihn als
fremd, hängt ein Schloss daran und sperrt ihn zu, obwohl jedes Mitglied
ihn pflegen darf. Genau daran wäre `kalender_verwalten_page.dart` sonst
kaputtgegangen.

Deshalb kommt die Antwort **vom Server** und steht am Kalender:

```dart
k.darfSchreiben   // Termine hineinlegen  (may_write)
k.darfVerwalten   // umbenennen, abholen  (may_manage)
k.gehoert(ichId)  // gehört er MIR? — etwas anderes!
```

`gehoert` und `darfVerwalten` auseinanderzuhalten ist der Punkt: beim
gemeinsamen Kalender ist das erste `false` und das zweite `true`. Die
Seiten fragen nach dem, was sie meinen — „darf ich das anfassen" beim
Knopf, „gehört er mir" beim Untertitel.

### Wo die Schalter stehen, und warum dort

Der Schalter „die anderen dürfen mitlesen" steht auf der **Haushaltsseite**
und nicht in `kalender_verwalten_page.dart`. Er ist eine Entscheidung über
den Haushalt und gehört neben die Finanz-Stufe und die MCP-Freigabe — die
drei Dinge, die jedes Mitglied für sich entscheidet. Zwischen Farbe und
ICS-Adresse stünde er da wie eine Einstellung des Kalenders.

Sichtbar ist er trotzdem an beiden Orten: in der Kalenderverwaltung steht
er im Untertitel („im Haushalt sichtbar"). **Gestellt** wird er nur an
einer Stelle.

Der Satz darüber — „2 von 3 deiner Kalender laufen im Haushalt mit" —
steht in `Haushaltssicht.kalenderSatz()`, wie `mitrechnenSatz` und
`freigabeSatz` und aus demselben Grund: eine Seite, die beim Aufbau lädt,
lässt sich nicht prüfen, die Regel dahinter schon.

Anders als `mitrechnenSatz` schweigt er **nicht**, wenn alle freigegeben
sind. Dort ist Vollständigkeit der Normalfall; hier ist es eine Preisgabe,
und die möchte man an einer Stelle nachlesen können, statt Schalter für
Schalter durchzugehen.

### Der Import fragt jetzt „wohin"

`planner_import_dialog.dart` zeigt oben eine **Liste der eigenen und
gemeinsamen Kalender**, vorgewählt ist der Standardkalender.

Vorher fragte der Dialog nach Quelle und Termintyp und schwieg darüber, wo
die Termine landen — sie fielen in den Standardkalender, und damit war die
Trennung nach Kalendern für den Import wirkungslos. Bei einer Datei mit
dreihundert Terminen merkt man das erst hinterher, und dann ist es
Handarbeit.

Die Liste zeigt nur, wohin man **schreiben** darf. Ein fremder,
freigegebener Kalender steht nicht dabei: eine Freigabe öffnet ihn zum
Lesen, und stünde er da, liefe der Import in ein 403 — nachdem der Nutzer
die Datei gewählt hat.

**Es gab den Import zweimal**, und das ist jetzt bereinigt:
`PlannerService.importIcs` (ohne Kalender) ist gelöscht, es gilt
`PlannerService.importieren` (mit `calendarId`). Der zweite Weg im
Kalender-Verwalten-Dialog benutzte schon immer den richtigen.

---

## 6. Das Haushaltsbuch rechnet die Zukunft, der Planer speichert sie

Beide zeigen wiederkehrende Dinge, beide reden von Serien — und mit der
Zukunft machen sie das Gegenteil. Wer vom einen aufs andere schliesst,
liegt falsch.

| | Planer | Haushaltsbuch |
|---|---|---|
| Künftige Vorkommen | echte Termine, 183 Tage im Voraus angelegt | **gerechnet**, nie gespeichert |
| Woher | `GET /planner` | `GET /finanzen/vorschau` |
| Datenklasse | `PlannerEntry` mit `id` | `Geplant` — **ohne `id`** |
| Bearbeitbar | ja, mit Geltungsbereich (nur dieser / folgende / alle) | nein; man ändert die Serie oder ihre Betragsstaffel |

Der Grund liegt im Backend und steht dort ausführlich
(`OwnAPI/ARCHITEKTUR.md` §5): ein Termin in drei Monaten *ist* schon ein
Termin — das Telefon muss ihn ohne Server einplanen können. Die Miete im
Mai ist dagegen eine Erwartung; wäre sie gespeichert, stünden beim ersten
Mietanstieg 180 Zeilen falsch da.

Für die App folgen daraus drei Dinge, und jedes davon ist eine Stelle,
an der es sonst kaputtgeht:

* **Eine Vorschauzeile darf nicht aussehen wie eine Buchung.** `_Vorschau`
  in `finanzen_page.dart` zeichnet sie blasser, mit Rand und nicht
  antippbar. Sähe sie gleich aus, würde jemand sie ändern wollen — und
  die Änderung wäre beim nächsten Laden weg, ohne Fehlermeldung.
* **Die Kachel `finanzen.faellig` speist sich aus der Vorschau, nicht aus
  Buchungen.** Die Kachelfilter greifen dort bewusst **nicht**: sie sind
  für Buchungen gebaut, und eine Vorschauzeile ist keine.
* **`FinanzService.nachbuchen()` läuft vor jedem Laden der Monatsseite**
  und darf scheitern (wer nur lesen darf, bekommt 403 und soll sein
  Kassenbuch trotzdem sehen). Das ist derselbe Gedanke wie die vier
  Auslöser von `ErinnerungsAbgleich` in §2: ein Hintergrundlauf, der
  einmal ausfiel, darf nicht bedeuten, dass die Miete fehlt.

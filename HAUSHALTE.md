# HAUSHALTE.md — das übernächste Projekt

Mehrere Personen, die Teile der App gemeinsam benutzen: dieselben
Rezepte, denselben Vorrat, dieselben Einkaufszettel — und einen
Finanzüberblick, der die Kassen aller Mitglieder zusammenrechnet.

Diese Datei ist der Bauplan, nicht die Beschreibung eines fertigen
Bereichs. Sie geht durch **beide Repos** und ist deutlich größer als der
Ausgaben-Tracker. Gegenstück und Vorbild: `AUSGABEN-TRACKER.md`.

## Voraussetzung: der Ausgaben-Tracker muss gemergt sein

Nicht „sollte" — **muss**. Dieser Plan verweist auf Dinge, die es auf
`main` erst danach gibt:

* `app/db/sql/031_finanzen.sql` — die Migration hier ist die **032**.
  Ohne 031 stimmt die Nummer nicht.
* `finance_accounts`, an die §3.2 ein `household_id` hängt.
* `AUSGABEN-TRACKER.md`, auf das §2.4 und §14 sich beziehen.

Die neun PRs, in dieser Reihenfolge, Backend vor App:

```
OwnAPI:  #24 → #25 → #26 → #27
OwnApp:  #85 (Bauplan), #86 → #87 → #88 → #89
```

Nach jedem Merge die Basis des nächsten PRs von seinem Vorgänger auf
`main` umstellen und nachsehen, ob die Änderung wirklich dort steht:

```bash
gh pr view <n> --json baseRefName -q .baseRefName
```

**Wer vorher anfängt, baut auf Sand.**

---

## 1. Das Leitprinzip: Koexistenz

**Haushalte stehen neben der persönlichen App, nicht darüber.**

Das ist die Zeile, aus der alles Weitere folgt, und sie ist die Antwort
auf die Frage, an der solche Umbauten sonst scheitern: *was passiert mit
dem, der nicht mitmacht?*

```
Kein Haushalt        →  App wie heute. Kein Haushalts-Menü, nichts fehlt.
Haushalt angelegt    →  eine zweite Ebene erscheint.
Im Haushalt          →  „Meine Rezepte"   neben   „Unsere Rezepte".
```

Wer in keinem Haushalt ist, merkt vom ganzen Modul nichts. Kein leerer
Abschnitt, kein ausgegrauter Menüpunkt, keine Erklärung, warum hier
nichts steht — der Bereich existiert für ihn einfach nicht.

Das ist auch der Grund, warum es **keinen Ein-Personen-Haushalt** gibt.
Er wäre eine leere Hülle, die man anlegen, benennen und verwalten müsste,
ohne dass irgendetwas dadurch besser würde.

---

## 2. Die sechs Entscheidungen

### 2.1 `household_id` leer heißt persönlich

Ein Objekt gehört entweder einer Person (wie heute) oder einem Haushalt.
Kein drittes.

### 2.2 Höchstens ein Haushalt je Person

Das erspart der ganzen App einen **Haushalts-Umschalter**. Bei mehreren
Haushalten bräuchte jede Abfrage einen Kontext („welcher ist gerade
gemeint"), jede Seite eine Anzeige davon, und jedes Anlegen eine
Zuordnung. Mit genau einem reicht „meins" und „unseres".

Falls sich das je ändern soll: die Mitgliedschaft steht in einer eigenen
Tabelle, nicht als Feld am Nutzer. Der Umbau wäre dann eine Sache der
Oberfläche, nicht des Datenmodells.

### 2.3 Einzelfreigaben bleiben

Drei Stufen, nicht zwei:

| Stufe | Wie |
|---|---|
| privat | `household_id` leer, kein Mitglied |
| an Einzelne freigegeben | `shopping_list_members`, `calendar_members`, `finance_account_members` |
| dem Haushalt gehörend | `household_id` gesetzt |

Die Mitgliedertabellen sind gebaut, geprüft und lösen einen Fall, den der
Haushalt nicht abdeckt: „diese eine Liste nur mit meiner Schwester".

### 2.4 Nicht alles wird haushalts-eigen

| bleibt global | wird haushalts-eigen |
|---|---|
| Einheiten, Zutaten, Kategorien, Läden | Rezepte, Vorrat, Einkaufslisten |
| | Preise, Essensplan |
| | Kassen und Buchungen |

**Warum die Stammdaten draußen bleiben:** „Gramm" gehört keinem
Haushalt. Wären Einheiten haushalts-eigen, legte jeder neue Haushalt
Gramm, Liter, Stück und Esslöffel neu an, **bevor** er das erste Rezept
erfassen kann. Bei Zutaten dasselbe — „Mehl" ist Vokabular, kein Besitz.

Migration 026 hat `units` und `ingredients` genau deshalb schon einmal
aus `recipes:write` herausgetrennt: sie dienen mehreren Zwecken und
gehören keinem Bereich allein. Sie jetzt einem *Haushalt* zuzuschlagen
wäre derselbe Fehler eine Etage höher.

**Läden bleiben global, Preise nicht.** Aldi ist Aldi. Was ein Haushalt
weiß, ist der *Preis* — und der ist regional und zeitlich verschieden.
Das Preisgedächtnis hängt ohnehin an *(Bezeichnung, Laden)*; nur die
erste Hälfte davon ist privat.

### 2.5 Finanz-Sichtbarkeit entscheidet jedes Mitglied für sich

Nicht der Haushalt, nicht sein Ersteller. Vier Stufen:

| Stufe | Was die anderen sehen |
|---|---|
| `nichts` | gar nichts — **Vorgabe beim Beitritt** |
| `summe` | Einnahmen, Ausgaben, Saldo des Zeitraums |
| `kategorien` | zusätzlich die Verteilung nach Kategorie |
| `alles` | einzelne Buchungen |

Warum vier und nicht zwei: „nur Summen" ist nicht eindeutig. Eine
Verteilung nach Kategorie ist selbst schon halb ein Beleg — *„Freizeit:
400 €"* verrät einiges.

**Die Vorgabe ist `nichts`, und das ist die Zeile, die man leicht falsch
herum baut.** Wer eingeladen wird, gibt nichts preis, bis er beim
Annehmen ausdrücklich etwas anderes einstellt. Bis dahin sehen die
vorhandenen Mitglieder von ihm keine Zahl.

### 2.6 `:read_all` bedeutet künftig „alle im eigenen Haushalt"

Das ist ein **Vorschlag**, keine getroffene Entscheidung — s. §12.

Heute heißt `shopping:read_all` „alle Einkaufslisten aller Personen".
Mit Haushalten wird das mehrdeutig: alle im Haushalt, oder alle
überhaupt? Für `planner:read_all` und `finance:read_all` dasselbe.

Vorschlag: `:read_all` heißt „alle im eigenen Haushalt". Für echtes
Systemweit bleibt die Admin-Wildcard. Das stimmt auch fachlich — das
Küchentablet, das an diesen Rechten hängt, steht in *einer* Küche.

---

## 3. Datenmodell

### 3.1 Migration `app/db/sql/032_haushalte.sql`

Nächste freie Nummer nach `031_finanzen.sql`.

**Diese Migration ist nicht rein additiv** — sie fügt Spalten hinzu *und*
ordnet Bestandsdaten zu. Nach `OwnAPI/SKILLS.md` §1 ist das ein Fall zum
**vorher fragen**. `update.sh` zieht zwar einen Abzug, aber eine
gelaufene Migration lässt sich nicht zurücknehmen.

```sql
CREATE TABLE IF NOT EXISTS households (
  id INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(80) NOT NULL,
  owner_id VARCHAR(36) NOT NULL,
  color VARCHAR(7) NOT NULL DEFAULT '#0EA5E9',
  created_at DATETIME NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_haushalt_besitzer
    FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
) COLLATE=utf8mb4_general_ci;

-- Mitgliedschaft als eigene Tabelle und NICHT als Feld am Nutzer.
--
-- Heute darf jeder nur in einem Haushalt sein, und ein
-- `users.household_id` waere einfacher. Die Tabelle kostet fast nichts
-- und laesst die Entscheidung umkehrbar: mehrere Haushalte waeren dann
-- eine Sache der Oberflaeche, nicht des Schemas.
--
-- Die Einmaligkeit erzwingt der UNIQUE-Index auf user_id -- also die
-- Datenbank und keine Abfrage.
CREATE TABLE IF NOT EXISTS household_members (
  household_id INT NOT NULL,
  user_id VARCHAR(36) NOT NULL,
  rolle ENUM('besitzer','mitglied') NOT NULL DEFAULT 'mitglied',
  -- Was die anderen von den Finanzen dieses Mitglieds sehen duerfen.
  -- Vorgabe ist NICHTS: wer beitritt, gibt nichts preis, bis er es
  -- ausdruecklich einstellt.
  finanz_sicht ENUM('nichts','summe','kategorien','alles')
    NOT NULL DEFAULT 'nichts',
  beigetreten_at DATETIME NULL,
  PRIMARY KEY (household_id, user_id),
  UNIQUE KEY uq_mitglied_nutzer (user_id),
  CONSTRAINT fk_mitglied_haushalt
    FOREIGN KEY (household_id) REFERENCES households(id) ON DELETE CASCADE,
  CONSTRAINT fk_mitglied_person
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) COLLATE=utf8mb4_general_ci;

-- Einladungen sind ein eigener Zustand, kein Mitglied mit Flag.
--
-- Eine Einladung hat einen Absender, einen Empfaenger und einen
-- Ausgang -- und sie muss sich zurueckziehen und ablehnen lassen, ohne
-- dass dabei eine halbe Mitgliedschaft entsteht.
CREATE TABLE IF NOT EXISTS household_invites (
  id INT NOT NULL AUTO_INCREMENT,
  household_id INT NOT NULL,
  user_id VARCHAR(36) NOT NULL,
  eingeladen_von VARCHAR(36) NOT NULL,
  zustand ENUM('offen','angenommen','abgelehnt','zurueckgezogen')
    NOT NULL DEFAULT 'offen',
  created_at DATETIME NULL,
  beantwortet_at DATETIME NULL,
  PRIMARY KEY (id),
  KEY idx_einladung_person (user_id, zustand),
  CONSTRAINT fk_einladung_haushalt
    FOREIGN KEY (household_id) REFERENCES households(id) ON DELETE CASCADE,
  CONSTRAINT fk_einladung_person
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) COLLATE=utf8mb4_general_ci;
```

### 3.2 Die Spalte, die überall dazukommt

```sql
ALTER TABLE <tabelle> ADD COLUMN household_id INT NULL,
  ADD KEY idx_<t>_haushalt (household_id),
  ADD CONSTRAINT fk_<t>_haushalt
    FOREIGN KEY (household_id) REFERENCES households(id) ON DELETE SET NULL;
```

Betroffen: `Recipe`, `PantryItem`, `shopping_lists`, `article_prices`,
`MealPlanEntry`, `finance_accounts`.

**`ON DELETE SET NULL`, nicht `CASCADE`.** Löst sich ein Haushalt auf,
sollen die Rezepte nicht mitgehen — sie fallen an den Besitzer zurück.
Was mit den Daten eines aufgelösten Haushalts passiert, ist §7.

### 3.3 Die Spalte, die manchen Tabellen fehlt

Hier liegt der Haken: **`Recipe` und `PantryItem` haben heute überhaupt
keinen Besitzer** — weder `household_id` noch `user_id`. Sie sind global.

Sie brauchen also **beides**: `owner_id` für den persönlichen Fall und
`household_id` für den geteilten. Ohne `owner_id` gäbe es kein
„persönliches Rezept", und die Koexistenz aus §1 wäre nicht herstellbar.

---

## 4. Die Migration der Bestandsdaten

Der heikelste Teil, und er läuft genau einmal.

```sql
-- Ein Haushalt aus den vorhandenen Nutzern. Das entspricht der
-- Wirklichkeit: die App wird von einem Haushalt benutzt, und alles, was
-- heute besitzerlos herumliegt, gehoert ihm gemeinsam.
INSERT INTO households (name, owner_id, created_at)
  SELECT 'Haushalt', id, NOW() FROM users ORDER BY created_at LIMIT 1;

INSERT INTO household_members (household_id, user_id, rolle, finanz_sicht,
                               beigetreten_at)
  SELECT h.id, u.id,
         CASE WHEN u.id = h.owner_id THEN 'besitzer' ELSE 'mitglied' END,
         'nichts',
         NOW()
  FROM users u CROSS JOIN households h;

-- Alles, was heute niemandem gehoert, gehoert ab jetzt dem Haushalt.
UPDATE Recipe      SET household_id = (SELECT id FROM households LIMIT 1);
UPDATE PantryItem  SET household_id = (SELECT id FROM households LIMIT 1);
UPDATE article_prices SET household_id = (SELECT id FROM households LIMIT 1);
UPDATE MealPlanEntry  SET household_id = (SELECT id FROM households LIMIT 1);
```

**`finanz_sicht` startet auf `nichts`, auch bei den Bestandsmitgliedern.**
Niemand hat je zugestimmt, seine Finanzen zu zeigen — eine Migration ist
kein Einverständnis. Wer etwas freigeben will, stellt es danach ein.

**Einkaufslisten und Kassen bleiben persönlich.** Sie haben schon einen
Besitzer, und der hat sich etwas dabei gedacht. Wer eine Liste dem
Haushalt geben will, tut das in der App.

> **Vor dem Ausrollen fragen.** Diese Migration ordnet Daten zu und ist
> nicht umkehrbar. Der Abzug von `update.sh` ist die einzige Rückfahrkarte.

---

## 5. Rechte

Keine neuen Bereiche, aber zwei neue Rechte:

```python
HOUSEHOLD_MANAGE = "household:manage"   # anlegen, einladen, verwalten
```

Ein Recht, nicht zwei: wer einen Haushalt führen darf, darf ihn auch
anlegen. Es gehört in `RECHTE_HAUSHALT` — sonst kann im Haushalt niemand
einen Haushalt anlegen, und das wäre komisch.

**Der Katalog-Kommentar in `permissions.py` wird falsch** und muss neu
geschrieben werden. Heute steht dort:

> „Bei den geteilten Bereichen (Vorrat, Einkauf, Rezepte, Zutaten,
> Einheiten, Läden) gibt es keinen Eigentümer — dort ist das Recht der
> einzige Schutz."

Das gilt nach dem Umbau nur noch für Zutaten, Einheiten, Kategorien und
Läden. Für Vorrat, Rezepte und Preise schützt künftig der Haushalt.

Dazu §2.6: die drei `:read_all` bekommen eine neue Bedeutung.

---

## 6. Die Einladung

Ein Ablauf mit Zuständen, kein Knopf.

```
Besitzer lädt ein          →  Einladung `offen`
  Eingeladener nimmt an    →  Pop-up „Was dürfen die anderen sehen?"
                           →  Mitglied, finanz_sicht wie gewählt
  Eingeladener lehnt ab    →  `abgelehnt`, nichts passiert
  Besitzer zieht zurück    →  `zurueckgezogen`
```

Drei Regeln, die im Ablauf stecken:

**Vor dem Annehmen sieht niemand etwas.** Weder die vorhandenen
Mitglieder vom Eingeladenen noch umgekehrt. Eine offene Einladung ist
eine Frage, keine halbe Mitgliedschaft.

**Das Pop-up beim Annehmen ist nicht überspringbar.** Es hat eine
Vorgabe (`nichts`), also kann man es wegtippen — aber es muss erscheinen,
damit niemand später behaupten kann, er habe es nicht gewusst.

**Wer schon in einem Haushalt ist, kann nicht angenommen werden.** Der
Unique-Index auf `user_id` verhindert es ohnehin; die Oberfläche soll es
vorher sagen, statt einen Datenbankfehler zu zeigen.

---

## 7. Der Ersteller und das Ende

| Fall | Was passiert |
|---|---|
| Mitglied verlässt den Haushalt | seine persönlichen Sachen bleiben seine; Haushaltssachen bleiben beim Haushalt |
| Besitzer verlässt den Haushalt | **geht nicht**, solange andere drin sind — er übergibt erst |
| Letztes Mitglied geht | Haushalt wird aufgelöst |
| Haushalt aufgelöst | `household_id` wird überall `NULL` → die Daten fallen an den Besitzer |

Der zweite Fall ist der, den man vergisst. Ein Haushalt ohne Besitzer hat
niemanden, der einladen oder auflösen darf — und die Daten hängen fest.

---

## 8. Backend-Arbeit je Modul

Für jedes haushalts-eigene Modul dasselbe Muster:

```python
def sichtbare_<dinger>(db, user_id, nur_haushalt=False, nur_eigene=False):
    """Eigene und die des Haushalts -- oder ausdruecklich nur eines."""
```

Und in jedem Endpunkt die Prüfung „gehört mir **oder** meinem Haushalt".
Das ist die Arbeit: **sie fällt in jedem Endpunkt von sechs Modulen an.**

```
app/models/household.py              drei Klassen
app/schemas/haushalte.py
app/services/haushalt_service.py     Sichtbarkeit an EINER Stelle
app/api/endpoints/haushalte.py
app/db/sql/032_haushalte.sql
```

Dazu angefasst: `recipes.py`, `pantry.py`, `shopping_lists.py`,
`meal_plan.py`, `finanzen.py` und ihre Dienste.

### Der Finanzteil ist der eigene Fall

`GET /haushalt/finanzen?von=&bis=` rechnet über die Kassen **aller
Mitglieder**, aber nur so weit, wie jedes einzelne es erlaubt:

```python
for mitglied in mitglieder:
    if mitglied.finanz_sicht == "nichts":
        continue                      # zählt nicht mal in die Summe
    ...
```

**Ein Mitglied auf `nichts` fehlt in der Haushaltssumme.** Das muss
dastehen („2 von 3 Mitgliedern rechnen mit"), sonst hält jemand eine
unvollständige Summe für die Wahrheit — derselbe Gedanke wie bei
`ohne_preis` und `ohne_zutat`.

---

## 9. App-Arbeit

```
lib/dataclasses/haushalt.dart
lib/dataservice/haushalt_service.dart
lib/tabs/haushalt/
    haushalt_page.dart          anlegen, Mitglieder, Einladungen
    einladung_dialog.dart       das Pop-up mit der Finanz-Sichtbarkeit
    haushalt_finanzen_page.dart die zusammengerechnete Übersicht
```

**Die Umschaltung „Meins / Unseres"** braucht jede betroffene Seite —
Rezepte, Vorrat, Einkaufslisten, Essensplan, Haushaltsbuch. Als
`SegmentedButton` im Kopf, wie die Richtung im Buchungsdialog.

**Und sie verschwindet vollständig, wenn man in keinem Haushalt ist.**
Das ist §1 in einer Zeile Code — und die Stelle, an der das Leitprinzip
kaputtgeht, wenn jemand sie vergisst.

Anschlussstellen wie beim Tracker: `main.dart`, `drawer.dart`,
**alle vier Karten** in `rechte_zuordnung.dart`, `DashboardData` an
**zwei** Bauplätzen (`dashboard_page.dart`, `tablet_seite.dart` —
`home.dart` ist unerreichbar).

---

## 10. Tests

Backend:

* Wer in keinem Haushalt ist, sieht genau das, was er heute sieht.
  **Der wichtigste Test des ganzen Vorhabens** — er hält §1 fest.
* Haushaltsrezept ist für beide Mitglieder da, für Dritte nicht.
* Persönliches Rezept bleibt persönlich, auch im Haushalt.
* Einladung: annehmen, ablehnen, zurückziehen, doppelt einladen.
* Wer schon Mitglied ist, kann nicht beitreten.
* `finanz_sicht` startet auf `nichts` — auch nach der Migration.
* Jede Stufe gibt genau so viel heraus wie erlaubt (vier Tests).
* Ein Mitglied auf `nichts` fehlt in der Summe **und wird gemeldet**.
* Besitzer kann nicht gehen, solange andere drin sind.
* Haushalt auflösen gibt die Daten zurück, löscht sie nicht.

App: die Sichtbarkeitsregel als reine Funktion, damit sie prüfbar ist —
derselbe Kunstgriff wie bei `finanz_rechnung.dart`.

Zu jedem Test die Gegenprobe.

---

## 11. Reihenfolge

| # | Repo | Inhalt | Danach benutzbar? |
|---|---|---|---|
| 1 | OwnAPI | Migration, Modelle, Recht, Haushalt anlegen/verwalten, Einladungen | — |
| 2 | OwnApp | Haushaltsseite, Einladungen annehmen, das Pop-up | **ja** — Haushalt existiert |
| 3 | OwnAPI | Einkaufslisten + Essensplan haushaltsfähig | |
| 4 | OwnAPI | Rezepte + Vorrat + Preise haushaltsfähig (**der Brocken**) | |
| 5 | OwnApp | „Meins / Unseres" auf allen betroffenen Seiten | **ja** — vollständig |
| 6 | OwnAPI | Haushalts-Finanzübersicht mit Sichtbarkeitsstufen | |
| 7 | OwnApp | Haushalts-Finanzseite | |

PR 4 ist der, bei dem es weh tut: zwei Module ohne jeden Besitzer
bekommen zwei neue Spalten und eine neue Sichtbarkeitsregel in jedem
Endpunkt.

### Zum Stapeln — dieselbe Falle wie beim Tracker

**PR 3 bis 7 hängen an PR 1** (Tabellen und Modelle) bzw. an PR 2. Von
`main` abgezweigt lassen sie sich nicht einmal übersetzen.

`SKILLS.md` §7 warnt vor gestapelten PRs, und die Warnung ist gut — sie
meint aber **unnötiges** Stapeln. Eine echte Abhängigkeit verschwindet
nicht dadurch, dass man von `main` abzweigt; sie wird dann nur zu einem
PR, der nicht baut.

Zwei Dinge gelten dann:

**Nach dem Merge des unteren PRs die Basis umstellen** und nachprüfen
(`gh pr view <n> --json baseRefName -q .baseRefName`).

**Auf einem gestapelten PR läuft keine CI.** Beide Repos lösen ihre
Arbeitsabläufe nur für `pull_request: branches: [main]` aus. Ein PR mit
anderer Basis bekommt deshalb keine Häkchen — nicht weil etwas rot wäre,
sondern weil nichts läuft. Dann **vor dem Öffnen lokal ausführen, was die
CI ausführen würde**, und das Ergebnis in den PR-Text schreiben:

```bash
# OwnAPI – dasselbe Image wie die CI
docker build -q -f Dockerfile.test -t ownapi-test . \
  && docker run --rm ownapi-test pytest -q

# OwnApp
flutter analyze && flutter test
```

Das ist beim Ausgaben-Tracker jedem einzelnen PR ab dem dritten
passiert; `AUSGABEN-TRACKER.md` §8 beschreibt es ausführlicher.

### Die Reihenfolge beim Mergen: erst umhängen, dann mergen

Das ist beim Ausgaben-Tracker schiefgegangen, und zwar sofort beim ersten
PR.

`gh pr merge <n> --merge --delete-branch` hängt die darüberliegenden PRs
**nicht** um. GitHub **schließt** sie, weil ihre Basis verschwindet — und
danach lassen sie sich nicht wieder öffnen, weil zum Öffnen der
Basis-Branch existieren muss. Henne und Ei.

Deshalb in dieser Reihenfolge:

```bash
# 1. ALLE Kinder auf main umhängen, solange die Basis noch existiert
gh pr edit <kind> --base main

# 2. Erst danach den unteren PR mergen
gh pr merge <eltern> --merge
```

Ist es doch passiert, hilft nur, den Basis-Branch kurz wiederherzustellen:

```bash
git push origin <alter-sha>:refs/heads/<geloeschter-branch>
gh pr reopen <n>
gh pr edit <n> --base main
git push origin --delete <geloeschter-branch>
```

Die Commits sind dabei nie in Gefahr — sie liegen im Branch des Kindes.
Nur der PR mitsamt seinem Text hängt an der Basis.

### Ein Basiswechsel löst keine CI aus

Der Satz „sobald die Basis auf `main` steht, läuft die CI von selbst
nach" stand hier und war falsch.

`pull_request` feuert nur bei `opened`, `synchronize` und `reopened`. Ein
`--base`-Wechsel ist keins davon: der PR zeigt danach auf `main`, hat
aber weiterhin **kein einziges Häkchen**.

Schließen und wieder öffnen löst sie aus, ohne die Historie mit
Leer-Commits zu verschmutzen:

```bash
gh pr close <n> && gh pr reopen <n>
until gh pr checks <n> 2>/dev/null | grep -qE "pass|fail"; do sleep 20; done
gh pr checks <n>
```

Beim Tracker sind so sechs PRs zum ersten Mal überhaupt durch die CI
gelaufen — nachdem sie längst geschrieben, geprüft und begründet waren.
Das ist der richtige Zeitpunkt dafür: **vor dem Merge, nicht danach.**

---

## 12. Offene Entscheidungen

1. **Bedeuten `shopping:read_all`, `planner:read_all` und
   `finance:read_all` künftig „alle im eigenen Haushalt"?** (§2.6) Mein
   Vorschlag ist ja. Betrifft das Küchentablet.
2. **Darf ein Haushaltsmitglied die persönlichen Sachen eines anderen
   sehen?** Nein — aber es lohnt, das einmal auszusprechen, bevor jemand
   es „praktisch" findet.
3. **Wie kommt eine Einladung an?** Über den bestehenden WebSocket wie
   `planner_changed`, oder erst beim nächsten Öffnen der App? Push gibt
   es nicht (siehe `ARCHITEKTUR.md`).
4. **Soll man Bestehendes in den Haushalt verschieben können?** „Dieses
   Rezept gehört ab jetzt uns." Naheliegend, aber eine eigene Aktion je
   Modul — vielleicht erst in einer zweiten Runde.

---

## 13. Was bewusst draußen bleibt

| | Warum |
|---|---|
| **Mehrere Haushalte je Person** | Braucht einen Umschalter und einen Kontext in jeder Abfrage. Das Datenmodell lässt es offen (§2.2). |
| **Rollen im Haushalt jenseits von Besitzer/Mitglied** | „Kind darf keine Finanzen sehen" ginge über eine eigene App-Rolle, nicht über den Haushalt. |
| **Haushalte über Server hinweg** | Nein. |
| **Einladung per Link an Fremde** | Eingeladen wird, wer schon ein Konto hat. Registrierung ist ein anderer Vorgang. |

---

## 14. Die Zeilen für ARCHITEKTUR.md

Wenn das steht, gibt es **drei** Arten, wie etwas geteilt wird, und der
nächste Leser muss wissen, welche wo gilt:

| Art | Bereiche | Wer sieht es |
|---|---|---|
| **Haushalt** | Rezepte, Vorrat, Einkaufslisten, Preise, Essensplan, Kassen | alle Mitglieder |
| **Einzelfreigabe** | Listen, Kalender, Kassen | wer eingetragen ist |
| **Global** | Einheiten, Zutaten, Kategorien, Läden | jeder mit dem Recht |

Dazu der Satz, der das Ganze trägt und den man sonst nicht rekonstruieren
kann: **Haushalte sind additiv. Wer keinen hat, verliert nichts.**

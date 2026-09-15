# AUSGABEN-TRACKER.md — das nächste Projekt

Ein Haushaltsbuch in OwnApp: Ausgaben und Einnahmen buchen, wiederkehrende
Posten als Regel hinterlegen, und Beträge, die sich im Lauf des Jahres
ändern, ohne Verlust der Vergangenheit fortschreiben.

Diese Datei ist der Bauplan, nicht die Beschreibung eines fertigen
Bereichs. Ist er gebaut, wandert das Bleibende nach `ARCHITEKTUR.md`
(beide Repos) und `README.md`, und diese Datei kann weg.

**Das Projekt geht durch beide Repos.** Der Löwenanteil liegt in
**OwnAPI**; die App hängt sich an das, was dort entsteht. Wer nur eine
Hälfte liest, baut die andere falsch.

**Enthalten seit dem ersten Nachtrag: die Brücke zur Einkaufsliste**
(§7). Abgehakte Posten × Preisgedächtnis ergeben einen Buchungsvorschlag.
Optional an jeder Stelle — wer nicht buchen will, merkt nichts davon.

**Nicht enthalten: die Bankanbindung.** Die ist ein eigenes Vorhaben mit
eigenen Fallstricken (Zustimmungsfristen, Kategorisierung, Abgleich) und
wartet, bis das hier steht und benutzt wird. Der Entwurf lässt ihr die
Tür offen — mehr bewusst nicht.

---

## 1. Die fünf Entscheidungen

Alles Weitere folgt aus diesen fünf. Wer eine davon umwirft, muss den
Rest neu denken.

### 1.1 Buchungen sind Tatsachen. Die Zukunft wird gerechnet.

**Der Planer macht es umgekehrt, und das ist kein Versehen auf einer der
beiden Seiten.**

`planner_recurrence_service.py` materialisiert Serientermine 183 Tage im
Voraus (`HORIZON_DAYS`) als echte Zeilen. Für Termine ist das richtig:
ein Termin in drei Monaten *ist* schon ein Termin, und das Telefon muss
ihn beim Betriebssystem einplanen können, ohne den Server zu fragen.

Für Geld stimmt das nicht. Die Miete im Mai ist keine Buchung, sondern
eine Erwartung. Materialisiert man sie, stehen beim ersten Mietanstieg
180 gespeicherte Zeilen falsch da, und jemand muss entscheiden, welche
davon angefasst werden.

Deshalb hier:

| Zeitraum | Woher |
|---|---|
| bis **heute** | echte Zeilen in `finance_bookings`, aus der Serie erzeugt |
| ab **morgen** | gerechnet aus Regel + Betragsstaffel, **nie gespeichert** |

Eine Vorschauzeile hat keine `id` und trägt `geplant: true`. Ändert sich
der Betrag, ändert sich die Vorschau von selbst — es gibt nichts zu
korrigieren.

### 1.2 Der Betrag hängt an einer Staffel, nicht an der Serie

Das ist die Antwort auf „alle drei Monate ändert sich der Abschlag", und
es ist derselbe Gedanke, der schon hinter `ArticlePrice` steht: Wissen
gehört an die Sache, nicht an den vergänglichen Datensatz.

```
finance_series            Strom, MONTHLY, am 1.
  └─ finance_series_amounts
       2025-01-01    89,00 €
       2025-04-01    94,50 €     ← Abschlag angepasst
       2025-07-01    91,00 €
```

Eine Buchung nimmt den Betrag, der **an ihrem Datum** galt. Damit fällt
dreierlei gleichzeitig weg:

* Der quartalsweise wechselnde Abschlag — der Fall, der das Projekt
  ausgelöst hat.
* Die rückwirkende Korrektur („der Januar war doch 91"): neue Zeile, die
  alte bleibt stehen.
* Die Frage „was habe ich letztes Jahr für Strom gezahlt": beantwortet
  sich aus den Buchungen, nicht aus einem Feld, das inzwischen
  überschrieben wurde.

Ein einzelnes `amount_cents` an der Serie wäre genau der Fehler, den
`ShoppingListItemPrice` gemacht hat — nur eine Etage höher.

### 1.3 Cent als Ganzzahl, niemals Fließkomma

`article_prices.price` ist `FLOAT`, und für ein Preisgedächtnis („Milch
war ungefähr 0,89") ist das in Ordnung. Ein Kassenbuch ist etwas anderes:
Fließkomma rundet, und über ein Jahr Summen driftet der Saldo um Beträge,
die man dann sucht.

**`amount_cents INT`**, Vorzeichen inklusive. Geteilt wird erst beim
Anzeigen. `INT` reicht: gut 21 Millionen Euro.

Das nachträglich umzustellen ist eine Datenmigration mit
Rundungsentscheidungen. Jetzt ist es ein Datentyp.

### 1.4 Eine Tabelle für Ausgaben und Einnahmen

Gehalt, Weihnachtsgeschenk und Wocheneinkauf sind derselbe Vorgang, nur
mit anderem Vorzeichen. Zwei Tabellen hießen: jede Auswertung zweimal
schreiben und jeden Saldo von Hand aus `einnahmen - ausgaben` bauen.

So ist der Saldo ein `SUM(amount_cents)`, und das Weihnachtsgeschenk ist
eine Buchung ohne Serie — dafür braucht es gar nichts Eigenes.

Negativ = Ausgabe, positiv = Einnahme. Die Oberfläche zeigt das nie als
Minuszeichen im Eingabefeld, sondern als Schalter „Ausgabe / Einnahme";
das Vorzeichen setzt der Dienst.

### 1.5 Kassen von Anfang an, nicht nachträglich

Eine `finance_accounts`-Zeile ist eine Kasse: „Haushalt", „Mein Giro",
später einmal ein echtes Bankkonto. Mit Besitzer und Mitgliedertabelle,
genau wie `shopping_lists` / `shopping_list_members` — das Muster ist im
Haus erprobt und beantwortet „welche Kassen sehe ich" mit einem Join.

Man könnte v1 auch ohne bauen und alles am Nutzer hängen. Davon rate ich
ab: eine Bankanbindung braucht zwingend ein Kontoobjekt, und wer es
später einführt, muss jede vorhandene Buchung zuordnen und die
Rechteprüfung umbauen. Jetzt sind es zwei Tabellen mit zusammen zehn
Spalten.

---

## 2. Datenmodell

### 2.1 Migration `app/db/sql/031_finanzen.sql`

Nächste freie Nummer ist **031** (030 ist die Stimmerkennung). Die
Migration ist rein additiv — keine Rückfrage nötig, siehe
`OwnAPI/SKILLS.md` §1.

Reihenfolge der `CREATE TABLE` ist nicht beliebig: `finance_bookings`
zeigt auf `finance_series`, also muss die Serie vorher da sein.

```sql
-- Haushaltsbuch: Kassen, Buchungen, Daueraufträge mit Betragsstaffel.
--
-- ZWEI DINGE, DIE MAN HIER NICHT ERWARTET:
--
-- 1. Beträge stehen in CENT als INT, nicht als FLOAT. Ein Kassenbuch
--    summiert über Jahre; Fließkomma driftet dabei um Beträge, die man
--    danach sucht. article_prices.price ist FLOAT -- das ist ein
--    Preisgedächtnis und kein Saldo, dort geht es.
--
-- 2. Die Zukunft steht NICHT in dieser Datenbank. Wiederkehrende Posten
--    werden nur bis heute gebucht; was danach kommt, rechnet
--    finanz_serien.vorschau() bei jeder Abfrage neu. Der Planer macht es
--    umgekehrt und materialisiert 183 Tage im Voraus -- dort ist ein
--    künftiger Termin schon eine Tatsache, hier ist ein künftiger Betrag
--    nur eine Erwartung.

CREATE TABLE IF NOT EXISTS finance_accounts (
  id INT NOT NULL AUTO_INCREMENT,
  owner_id VARCHAR(36) NOT NULL,
  name VARCHAR(80) NOT NULL,
  kind ENUM('bar','giro','sparen','kreditkarte') NOT NULL DEFAULT 'giro',
  color VARCHAR(7) NOT NULL DEFAULT '#3B82F6',
  -- Anfangsbestand beim Anlegen. Ohne ihn ist jeder Saldo eine Summe von
  -- Buchungen und kein Kontostand -- man müsste bei null anfangen und
  -- alles nachtragen.
  start_cents INT NOT NULL DEFAULT 0,
  order_index INT NOT NULL DEFAULT 0,
  created_at DATETIME NULL,
  PRIMARY KEY (id),
  KEY idx_kasse_besitzer (owner_id),
  CONSTRAINT fk_kasse_besitzer
    FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
) COLLATE=utf8mb4_general_ci;

-- Wer außer dem Besitzer mitschreiben darf. Eine Zeile je Person,
-- wie shopping_list_members.
CREATE TABLE IF NOT EXISTS finance_account_members (
  account_id INT NOT NULL,
  user_id VARCHAR(36) NOT NULL,
  PRIMARY KEY (account_id, user_id),
  CONSTRAINT fk_kassenmitglied_kasse
    FOREIGN KEY (account_id) REFERENCES finance_accounts(id) ON DELETE CASCADE,
  CONSTRAINT fk_kassenmitglied_nutzer
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) COLLATE=utf8mb4_general_ci;

-- Eigene Kategorien, NICHT die bestehende Tabelle `Category`.
-- Die hängt an Aufgaben und Rezepten. Migration 026 hat genau so eine
-- Vermischung schon einmal auftrennen müssen (recipes:write deckte auch
-- Zutaten und Einheiten ab); ein Auswahlfeld, in dem "Nudelgerichte"
-- neben "Miete" steht, ist der Anfang desselben Fehlers.
--
-- Geteilte Stammdaten ohne Besitzer, wie Shops: hier ist das Recht der
-- einzige Schutz.
CREATE TABLE IF NOT EXISTS finance_categories (
  id INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(80) NOT NULL,
  kind ENUM('ausgabe','einnahme','beides') NOT NULL DEFAULT 'ausgabe',
  color VARCHAR(7) NOT NULL DEFAULT '#64748B',
  icon VARCHAR(40) NULL,
  order_index INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
) COLLATE=utf8mb4_general_ci;

-- Die Regel eines wiederkehrenden Postens. Der Betrag steht NICHT hier,
-- sondern in finance_series_amounts -- siehe Kopf der Datei.
--
-- Kein QUARTERLY: das ist MONTHLY mit interval_n = 3. Ein eigener Wert
-- wäre ein zweiter Weg zum selben Ergebnis, und dann muss jede Rechnung
-- beide kennen. Dasselbe Vokabular wie planner_recurrences.
CREATE TABLE IF NOT EXISTS finance_series (
  id INT NOT NULL AUTO_INCREMENT,
  account_id INT NOT NULL,
  category_id INT NULL,
  title VARCHAR(120) NOT NULL,
  freq ENUM('DAILY','WEEKLY','MONTHLY','YEARLY') NOT NULL DEFAULT 'MONTHLY',
  interval_n INT NOT NULL DEFAULT 1,
  byweekday VARCHAR(20) NULL,     -- 'MO,WE,FR', nur bei WEEKLY
  bymonthday INT NULL,            -- 1..31, nur bei MONTHLY/YEARLY
  start_on DATE NOT NULL,
  end_on DATE NULL,
  -- Ausgesetzt statt gelöscht: eine gekündigte Versicherung soll aufhören
  -- zu buchen, ohne dass ihre Vergangenheit ihre Regel verliert.
  active TINYINT(1) NOT NULL DEFAULT 1,
  note VARCHAR(255) NULL,
  created_by VARCHAR(36) NULL,
  created_at DATETIME NULL,
  PRIMARY KEY (id),
  KEY idx_serie_kasse (account_id, active),
  CONSTRAINT fk_serie_kasse
    FOREIGN KEY (account_id) REFERENCES finance_accounts(id) ON DELETE CASCADE,
  CONSTRAINT fk_serie_kategorie
    FOREIGN KEY (category_id) REFERENCES finance_categories(id) ON DELETE SET NULL
) COLLATE=utf8mb4_general_ci;

-- Was die Serie ab wann kostet. Der Kern des Entwurfs.
--
-- Es gibt keine Gültigkeit BIS: die nächste Zeile beendet die
-- vorhergehende. Zwei Felder, die dasselbe sagen müssen, driften
-- irgendwann auseinander.
CREATE TABLE IF NOT EXISTS finance_series_amounts (
  id INT NOT NULL AUTO_INCREMENT,
  series_id INT NOT NULL,
  gueltig_ab DATE NOT NULL,
  amount_cents INT NOT NULL,
  note VARCHAR(255) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_staffel_serie_ab (series_id, gueltig_ab),
  CONSTRAINT fk_staffel_serie
    FOREIGN KEY (series_id) REFERENCES finance_series(id) ON DELETE CASCADE
) COLLATE=utf8mb4_general_ci;

-- Die Tatsache: hier ist Geld geflossen.
--
-- Negativ = Ausgabe, positiv = Einnahme. Eine Tabelle für beides, weil
-- Gehalt und Wocheneinkauf derselbe Vorgang mit anderem Vorzeichen sind
-- und der Saldo sonst überall von Hand zusammengesetzt werden müsste.
CREATE TABLE IF NOT EXISTS finance_bookings (
  id INT NOT NULL AUTO_INCREMENT,
  account_id INT NOT NULL,
  category_id INT NULL,
  booked_on DATE NOT NULL,
  amount_cents INT NOT NULL,
  title VARCHAR(120) NOT NULL,
  note VARCHAR(255) NULL,
  series_id INT NULL,
  -- Einzeln angefasst: das Nachbuchen rührt diese Zeile nicht mehr an.
  -- Gleiche Bedeutung wie PlannerEntry.is_detached.
  is_detached TINYINT(1) NOT NULL DEFAULT 0,
  -- Für später (Bank-, CAMT-, Bonimport): stabile Fremdkennung zur
  -- Dedup, genau wie planner_entries.external_uid beim ICS-Import.
  external_uid VARCHAR(255) NULL,
  created_by VARCHAR(36) NULL,
  created_at DATETIME NULL,
  PRIMARY KEY (id),
  KEY idx_buchung_kasse_datum (account_id, booked_on),
  KEY idx_buchung_kategorie (category_id),
  -- Die Doppelbuchungssperre. Entscheidend, dass die DATENBANK das
  -- entscheidet und nicht eine Abfrage im Dienst: nachbuchen() läuft aus
  -- dem Scheduler UND beim Öffnen der Seite, also womöglich gleichzeitig.
  --
  -- MySQL lässt mehrere NULL in einem UNIQUE-Index zu. Von Hand
  -- eingetippte Buchungen (series_id IS NULL) sind davon also nicht
  -- betroffen -- zweimal am selben Tag beim Bäcker bleibt möglich.
  UNIQUE KEY uq_buchung_serie_tag (series_id, booked_on),
  UNIQUE KEY uq_buchung_fremdkennung (account_id, external_uid),
  CONSTRAINT fk_buchung_kasse
    FOREIGN KEY (account_id) REFERENCES finance_accounts(id) ON DELETE CASCADE,
  CONSTRAINT fk_buchung_kategorie
    FOREIGN KEY (category_id) REFERENCES finance_categories(id) ON DELETE SET NULL,
  -- Löscht man eine Serie, bleiben ihre Buchungen: die Vergangenheit
  -- gehört dem Kassenbuch, nicht der Regel.
  CONSTRAINT fk_buchung_serie
    FOREIGN KEY (series_id) REFERENCES finance_series(id) ON DELETE SET NULL
) COLLATE=utf8mb4_general_ci;

-- Ein Satz Kategorien zum Anfangen. Ohne den steht der Nutzer vor einer
-- leeren Auswahlliste und muss erst Stammdaten pflegen, bevor er die
-- erste Ausgabe eintragen kann.
INSERT INTO finance_categories (name, kind, color, order_index) VALUES
  ('Lebensmittel',   'ausgabe',  '#22C55E',  1),
  ('Wohnen',         'ausgabe',  '#EF4444',  2),
  ('Strom & Gas',    'ausgabe',  '#F59E0B',  3),
  ('Mobilität',      'ausgabe',  '#3B82F6',  4),
  ('Versicherungen', 'ausgabe',  '#8B5CF6',  5),
  ('Abos & Verträge','ausgabe',  '#EC4899',  6),
  ('Freizeit',       'ausgabe',  '#14B8A6',  7),
  ('Sonstiges',      'beides',   '#64748B',  8),
  ('Gehalt',         'einnahme', '#16A34A',  9),
  ('Geschenke',      'beides',   '#F472B6', 10);
```

**Beim Schreiben der Datei beachten:** `migrate.py` wirft Kommentarzeilen
raus und zerlegt an `;`. Kein Semikolon in einen Kommentar setzen, der
stehenbleiben soll, und keine mehrzeiligen `/* */`-Kommentare verwenden —
die Regel greift nur bei `--` am Zeilenanfang.

### 2.2 Modelle

Alles in **eine** Datei `app/models/finance.py`, wie `shopping_list.py`
es vormacht. Fünf Klassen: `FinanceAccount`, `FinanceAccountMember`,
`FinanceCategory`, `FinanceSeries`, `FinanceSeriesAmount`,
`FinanceBooking`.

Die Klassenkommentare tragen die Begründungen aus §1 — der Code ist der
Ort, an dem sie gefunden werden.

---

## 3. Rechte

In `app/core/permissions.py`:

```python
FINANCE_READ = "finance:read"
FINANCE_WRITE = "finance:write"
FINANCE_READ_ALL = "finance:read_all"
```

Im `KATALOG`:

```python
Recht(FINANCE_READ, "Finanzen", "Eigene Kassen und Buchungen sehen"),
Recht(FINANCE_WRITE, "Finanzen", "Buchungen und Daueraufträge ändern"),
Recht(FINANCE_READ_ALL, "Finanzen", "Kassen aller Personen sehen"),
```

**`finance:read_all` muss aus `RECHTE_HAUSHALT` ausgeschlossen werden** —
in dieselbe Klammer wie `AI_CONFIGURE`, `TABLET_USE`, `PLANNER_READ_ALL`.
Wer es vergisst, gibt jedem im Haushalt Einblick in jede Kasse, ohne dass
das jemand entschieden hat. Genau das war bis Migration 029 bei
`planner:read_all` der Fall.

**Und es gehört nicht ans Tablet.** `sieht_alle_kalender()` zieht
`tablet:use` ausdrücklich mit herein; für Finanzen wäre das falsch. Das
Küchentablet hängt an der Wand und wird von jedem gelesen — Kontostände
gehören nicht darauf. Wer sie dort will, legt eine Kasse „Haushalt" an
und gibt sie frei. **Es darf also kein `sieht_alle_kassen()` nach dem
Vorbild von `sieht_alle_kalender()` geben.**

Bedeutung wie überall: `finance:read` heißt „darf den Bereich benutzen",
nicht „darf alle Kassen lesen". Die Besitzer- und Mitgliederprüfung sitzt
**dahinter**, nicht stattdessen.

Ausnahme, die ausdrücklich genannt gehört: `finance_categories` sind
geteilte Stammdaten ohne Besitzer. Dort ist das Recht der einzige Schutz
— wie bei Vorrat, Läden und Einheiten.

---

## 4. Backend

### 4.1 Dateien

```
app/models/finance.py                sechs Klassen
app/schemas/finanzen.py              Pydantic, "" → None normieren
app/services/finanz_service.py       CRUD, Rechteprüfung, Saldo, Auswertung
app/services/finanz_serien.py        die reine Rechnung -- s. 4.3
app/api/endpoints/finanzen.py        router, prefix "/finanzen"
app/db/sql/031_finanzen.sql
```

Registrieren in `app/api/router.py`:

```python
router.include_router(finanzen.router, prefix="/finanzen", tags=["Finanzen"])
```

`_hole_kasse(db, account_id, user, rechte, schreiben=False)` nach dem
Vorbild von `_hole_liste` in `shopping_lists.py`: 404 wenn es sie nicht
gibt, 403 mit klarem Text wenn sie einem nicht gehört, Mitlesen für
`finance:read_all` — **schreiben nie**.

### 4.2 Endpunkte

Jeder mit `require(...)`, sonst schlägt `test_endpoint_absicherung.py`
fehl (und das ist gut so).

| Methode | Pfad | Recht |
|---|---|---|
| GET | `/finanzen/kassen?alle=` | `finance:read` (+`read_all` für `alle`) |
| POST / PUT / DELETE | `/finanzen/kassen[/{id}]` | `finance:write` |
| POST / DELETE | `/finanzen/kassen/{id}/mitglieder/{uid}` | `finance:write` |
| GET | `/finanzen/kategorien` | `finance:read` |
| POST / PUT / DELETE | `/finanzen/kategorien[/{id}]` | `finance:write` |
| GET | `/finanzen/buchungen?kasse=&von=&bis=` | `finance:read` |
| POST / PUT / DELETE | `/finanzen/buchungen[/{id}]` | `finance:write` |
| GET | `/finanzen/serien?kasse=` | `finance:read` |
| POST / PUT / DELETE | `/finanzen/serien[/{id}]` | `finance:write` |
| POST | `/finanzen/serien/{id}/betrag` | `finance:write` |
| DELETE | `/finanzen/serien/{id}/betrag/{bid}` | `finance:write` |
| GET | `/finanzen/vorschau?von=&bis=` | `finance:read` |
| GET | `/finanzen/auswertung?von=&bis=` | `finance:read` |
| POST | `/finanzen/nachbuchen` | `finance:write` |

`/finanzen/auswertung` liefert Saldo, Summe der Einnahmen, Summe der
Ausgaben und die Verteilung je Kategorie — gerechnet im Backend, nicht in
der App. Die Kacheln brauchen genau das, und viermal dieselbe Summe über
alle Buchungen im Client zu bilden ist Verschwendung.

**`PUT /finanzen/buchungen/{id}` setzt `is_detached = 1`**, sobald die
Buchung zu einer Serie gehört. Ohne das überschreibt das nächste
Nachbuchen die Änderung wieder — derselbe Mechanismus wie beim Planer.

### 4.3 `finanz_serien.py` — die Rechnung

Vier Funktionen, **ohne Datenbankzugriff in den ersten beiden**. Genau
deshalb sind sie prüfbar (vgl. `OwnApp/SKILLS.md` §4: die Rechnung aus
der Seite ziehen — hier: aus dem Dienst).

```python
def faellige_termine(serie, von: date, bis: date) -> list[date]
def betrag_am(staffel: list[tuple[date, int]], tag: date) -> int | None
def vorschau(serien, staffeln, von, bis) -> list[GeplanteBuchung]
def nachbuchen(db, user_id: str, bis: date | None = None) -> int
```

**Randfälle, die entschieden sein müssen, bevor jemand tippt:**

| Fall | Regel |
|---|---|
| `bymonthday = 31`, Februar | auf den **letzten Tag des Monats** kürzen. `dateutil.rrule` mit `bymonthday=31` *überspringt* Monate ohne 31. — für eine Miete wäre das ein ausgefallener Monat. Deshalb MONTHLY **nicht** über rrule rechnen, sondern Monat für Monat mit Kürzung. |
| „letzter des Monats" | `bymonthday = 31` plus die Kürzungsregel. Kein eigener Sonderwert. |
| Fälligkeit fällt auf Wochenende/Feiertag | **nicht verschieben.** Eine Bank tut es, wir nicht: die Regel bleibt vorhersagbar, und der tatsächliche Tag steht ohnehin erst im Kontoauszug. |
| Buchungstag vor der ersten Staffelzeile | `betrag_am` gibt `None`, `nachbuchen` bucht nicht und protokolliert. Beim Anlegen einer Serie wird deshalb **erzwungen**, dass eine Staffelzeile mit `gueltig_ab <= start_on` existiert. |
| `gueltig_ab` genau am Buchungstag | die neue Stufe gilt (`<=`, nicht `<`). |
| Serie inaktiv (`active = 0`) | keine neuen Buchungen, keine Vorschau. Vorhandene bleiben. |
| Serie gelöscht | Buchungen bleiben, `series_id` wird `NULL` (Fremdschlüssel). |
| `nachbuchen` mit `bis` in der Zukunft | wird auf **heute** gekürzt. Die Zukunft wird nicht gebucht — siehe §1.1. |
| zweimal `nachbuchen` | der Unique-Index `uq_buchung_serie_tag` verhindert die zweite Zeile. `IntegrityError` abfangen und weiterzählen, nicht abbrechen. |

### 4.4 Auslöser für `nachbuchen`

Zwei, und beide sind nötig:

1. **Scheduler-Job**, täglich, in `app/core/scheduler.py` — neben
   `extend_planner_recurrences()` und nach demselben Muster (eigene
   Session, `try/except/finally`, eine Logzeile nur wenn etwas geschah).
2. **Beim Laden der Buchungsliste**, falls der letzte Lauf älter als ein
   Tag ist.

Warum beides: derselbe Grund, aus dem `ErinnerungsAbgleich.jetzt()` vier
Auslöser hat. Ein Hintergrundjob, der einmal nicht lief, darf nicht
bedeuten, dass die Miete im Kassenbuch fehlt.

---

## 5. App

### 5.1 Dateien

```
lib/dataclasses/finanzen.dart        Kasse, Buchung, Serie, Betragsstufe, Auswertung
lib/dataservice/finanz_service.dart  Netzzugriff -- kennung() nicht vergessen
lib/dataservice/finanz_rechnung.dart reine Rechnung: Formatierung, Summen, Monatsgrenzen
lib/tabs/finanzen/
    finanzen_page.dart      Monatsansicht: Saldo oben, Buchungen darunter, Blättern
    buchung_dialog.dart     Betrag, Ausgabe/Einnahme, Datum, Kategorie, Kasse, Notiz
    serien_page.dart        Daueraufträge, je Serie die Betragsstaffel
    kassen_page.dart        Kassen und Mitglieder -- Vorbild: einkaufslisten_page.dart
```

`finanz_rechnung.dart` ist kein Beiwerk, sondern der Grund, warum sich
hier überhaupt etwas testen lässt. Hinein gehören: Cent → „−47,83 €",
Monatsanfang/-ende, Summe je Kategorie, Saldo mit Anfangsbestand. Die
Seiten selbst laden beim Aufbau und sind damit nicht prüfbar — das ist
die bekannte Lücke, keine neue.

**`kennung()` übernehmen.** Eine leere `categoryId` als `''` an einen
Fremdschlüssel zu schicken bringt den Server zum Absturz, und im Browser
kommt es als CORS-Fehler an. `EinkaufService.kennung()` ist die Vorlage;
Dart lässt mit `?wert` nur `null` weg, nicht den leeren String.

### 5.2 Anschlussstellen — Checkliste

Wer eine davon vergisst, merkt es spät.

| Datei | Was |
|---|---|
| `lib/main.dart` | `AppRoutes.finanzen = '/finanzen'`, `finanzenSerien`, `kassen` + Einträge in `AppRoutes.routes` |
| `lib/widgets/drawer.dart` | **eigener Abschnitt** „Finanzen", nicht zu `_pantryItems`. `Icons.account_balance_wallet_outlined` |
| `lib/dataservice/rechte_zuordnung.dart` | **alle vier Karten**: `rechtJeRoute`, `rechtJeKachel`, `rechtJeQuelle`, `quelleJeKachel` |
| `lib/tabs/dashboard/custom/filter_fields.dart` | `FilterFields.finanzen` |
| `lib/tabs/dashboard/custom/tile_catalog.dart` | vier Quellen, s. u. |
| `lib/tabs/dashboard/custom/tile_spec.dart` | `DashboardData.finanzen` |
| **drei** Bauplätze von `DashboardData` | `tabs/home.dart:145`, `tabs/dashboard/dashboard_page.dart:609`, `tabs/tablet/tablet_seite.dart:176` |

Der letzte Punkt ist der, den man übersieht: `DashboardData` wird an drei
Stellen zusammengesetzt, und eine Kachel, die auf der einen Seite
funktioniert, bleibt auf der anderen leer, ohne einen Fehler zu melden.

Für das Tablet gilt dabei: Finanzdaten dort **nicht** laden, solange es
über `tablet:use` läuft und keine eigene Freigabe hat (§3).

### 5.3 Kacheln

Vier Einträge in `TileCatalog.sources`, und der Baukasten macht den Rest
— Editor, Filter, Speicherung, beide Übersichtsseiten.

| Schlüssel | Form | Was man sieht | Parameter |
|---|---|---|---|
| `finanzen.saldo` | `scalar` | Saldo des Monats | Monatsversatz, Kasse |
| `finanzen.kategorien` | `distribution` | Torte: wohin das Geld ging | Monatsversatz, Kasse |
| `finanzen.verlauf` | `series` | Linie über N Monate | Anzahl Monate, Kasse |
| `finanzen.faellig` | `list` | was diesen Monat noch kommt | Kasse |

`finanzen.faellig` speist sich aus der **Vorschau**, nicht aus Buchungen
— sie ist der sichtbare Teil von Entscheidung §1.1. Beim Bauen darauf
achten, dass sie ohne `id` auskommt.

Ein Parameter `_welcheKasse` nach dem Vorbild von
`TileParam.einkaufsliste` wäre nötig; solange es den nicht gibt, alle
sichtbaren Kassen zusammenrechnen und den Parameter nachreichen.

---

## 6. Tests

### 6.1 Backend (`pytest`, SQLite im Speicher)

```
tests/test_finanz_serien.py       die Rechnung, ohne Datenbank
tests/test_finanzen_rechte.py     fremde Kasse, Mitglied, read_all
tests/test_finanzen_buchungen.py  CRUD, Vorzeichen, is_detached
```

Was mindestens geprüft sein muss:

* `faellige_termine`: Monatswechsel, **31. im Februar**, `interval_n = 3`,
  `end_on` mittendrin, `start_on` nach `von`.
* `betrag_am`: drei Stufen, Stichtag genau auf `gueltig_ab`, Stichtag vor
  der ersten Stufe (→ `None`).
* `nachbuchen` zweimal hintereinander erzeugt **keine** zweite Zeile.
* `nachbuchen` fasst eine Buchung mit `is_detached = 1` nicht an.
* `vorschau` schreibt nichts in die Datenbank (hinterher zählen).
* Fremde Kasse lesen → 403; mit `finance:read_all` lesen → 200;
  mit `finance:read_all` **schreiben** → 403.

`test_endpoint_absicherung.py` läuft automatisch mit und findet einen
Endpunkt ohne `require(...)` von selbst.

### 6.2 App

```
test/finanz_rechnung_test.dart    Formatierung, Summen, Monatsgrenzen
test/finanz_kacheln_test.dart     die vier Quellen, Stil: custom_tiles_test.dart
test/drawer_rechte_test.dart      erweitern: ohne finance:read kein Menüpunkt
```

### 6.3 Die Gegenprobe

Für **jeden** neuen Test: Code kaputt machen, Test laufen lassen, rot
sehen, wiederherstellen. In diesem Projekt sind dabei schon mehrfach
Tests aufgefallen, die nichts prüften.

```bash
cp -r lib /tmp/lib-heil   # bzw. cp -r app /tmp/app-heil
```

---

## 7. Brücke: Einkaufsliste → Buchung

Stand vorher in §10 unter „bleibt draußen". Ist jetzt drin, auf
ausdrücklichen Wunsch — und zwar **optional an jeder Stelle**: die Liste
funktioniert weiter wie bisher, wer nicht buchen will, merkt nichts davon.

Die Idee: nach dem Einkauf hakt man ab. Das Preisgedächtnis weiß, was die
abgehakten Sachen im gewählten Laden zuletzt gekostet haben. Daraus wird
ein **Vorschlag** für eine Ausgabe — nicht die Buchung selbst.

### Die eine Sache, die man hier falsch machen kann

**Die Summe ist eine Schätzung, kein Kassenbon.** Sie kommt aus Preisen,
die irgendwann einmal notiert wurden. Wer sie ungeprüft bucht, füllt sein
Kassenbuch mit plausibel aussehender Erfindung — und das ist schlimmer
als eine Lücke, weil man es später nicht mehr erkennt.

Daraus folgen drei Regeln, die nicht verhandelbar sind:

1. Der Betrag steht im Dialog und ist **änderbar**, bevor gebucht wird.
   Der Bon in der Hand gewinnt gegen das Gedächtnis.
2. Die Buchung trägt in `note`, woher die Zahl kam („geschätzt aus
   Preisen, Wocheneinkauf bei Aldi, 3 Posten ohne Preis").
3. Posten ohne Preis werden **genannt und gezählt**, nicht stillschweigend
   weggelassen. Das ist dieselbe Regel, an der sich `in_den_vorrat` schon
   hält — dort kommen Positionen ohne Zutat als `ohneZutat` zurück, weil
   „wer zehn Sachen abhakt und drei gebucht bekommt, soll erfahren warum".

### Was NICHT von `Preisvergleich` übernommen wird

`lib/dataservice/preisvergleich.dart` rechnet bewusst auf **gemeinsamer
Grundlage**: nur Posten, für die *jeder* verglichene Laden einen Preis
hat. Das ist dort richtig — kennt man von Aldi drei Preise und von Rewe
fünfzehn, wäre Aldis kleinere Summe „eine Lüge aus wahren Zahlen".

Die Brücke vergleicht nicht, sie summiert für **einen** Laden. Die Regel
gilt hier also nicht: genommen wird jeder abgehakte Posten, für den
dieser Laden einen Preis kennt. Der Rest wird gemeldet.

Zwei Grenzen erbt sie trotzdem, und beide stehen schon im Kopf von
`preisvergleich.dart`:

* **Menge mal Preis stimmt nur bei Stückpreisen.** Stand der Preis für
  „500 g", wird er trotzdem mit der Postenmenge multipliziert — das
  Preisgedächtnis führt keine umrechenbaren Einheiten mit.
* Bei mehreren Einträgen je Laden gewinnt der günstigste.

### Backend

Eine dritte Funktion in `app/services/einkauf_bruecken.py`, neben
`aus_essensplan` und `in_den_vorrat`:

```python
def buchungsvorschlag(db, list_id: int, shop_id: str) -> dict:
    """Was die abgehakten Posten laut Preisgedaechtnis hier kosten.

    Rechnet nur. Geschrieben wird nichts -- die Buchung legt der
    Finanz-Endpunkt an, nachdem der Nutzer sie bestaetigt hat.
    """
    # -> {"laden": "Aldi", "summe_cents": 3418, "anzahl": 7,
    #     "posten": [{"name", "menge", "cents"}],
    #     "ohne_preis": ["Batterien", "Backpapier"]}
```

| Methode | Pfad | Recht |
|---|---|---|
| GET | `/einkauf/{list_id}/buchungsvorschlag?shop_id=` | `shopping:read` **und** `prices:read` |

Zwei Rechte an einem Endpunkt ist hier richtig und kein Sonderfall: er
liest aus beiden Bereichen. Wer keine Preise sehen darf, bekommt keinen
Vorschlag — und `prices:read` gibt es seit Migration 026 getrennt, genau
für solche Fälle.

**Der Endpunkt schreibt nichts.** Das ist dieselbe Trennung wie beim
Assistenten: Werkzeuge schlagen vor, Aktionen schreiben nach
Bestätigung. Ein `einkauf`-Endpunkt, der Finanzzeilen anlegt, würde zwei
Bereiche verkleben, die sonst nichts miteinander zu tun haben.

### Der Schutz gegen die Doppelbuchung

Hakt man ab, bucht, hakt weiter ab und bucht nochmal, stünde der Einkauf
zweimal im Kassenbuch. Dagegen hilft ein Feld, das es schon gibt:

```
external_uid = f"einkauf:{list_id}:{booked_on}"
```

`uq_buchung_fremdkennung (account_id, external_uid)` aus Migration 031
lässt die zweite Buchung dann nicht zu — **die Datenbank entscheidet**,
nicht eine Abfrage. Das Feld war für den späteren Bankimport gedacht;
dass es hier genauso passt, ist kein Zufall: es beantwortet beide Male
dieselbe Frage.

Der Client fängt den Konflikt ab und bietet an, die vorhandene Buchung zu
**ändern** statt eine zweite anzulegen. Zweimal am selben Tag im selben
Laden einkaufen ist selten; wer es tut, ändert den Betrag.

### App

In `lib/tabs/einkauf/einkaufsliste_page.dart`, neben dem Küchen-Symbol
(„in den Vorrat"), eine zweite Aktion:

```
🧾  Als Ausgabe buchen
```

Der Ablauf, vier Schritte:

1. **Laden wählen.** Vorbelegt mit dem günstigsten aus `Preisvergleich` —
   die Rechnung steht schon auf der Seite.
2. **Vorschlag holen.** Ein Aufruf, s. o.
3. **Dialog** — `buchung_dialog.dart` aus PR 2, vorbelegt mit Summe,
   Titel („Wocheneinkauf bei Aldi"), heutigem Datum, Kategorie
   „Lebensmittel" und der Kasse, die zuletzt benutzt wurde. Darunter ein
   Hinweis: *„Geschätzt aus 7 Preisen. 2 Posten ohne Preis: Batterien,
   Backpapier."*
4. **Buchen** über den normalen Weg (`POST /finanzen/buchungen`).

**Die Aktion ist nur sichtbar, wenn beides da ist** — `finance:write` und
mindestens ein Preis für die abgehakten Posten. Ein Knopf, der immer
„keine Preise bekannt" sagt, ist kein Angebot, sondern eine Enttäuschung.

### Tests

Backend, in `tests/test_einkauf_buchung.py`:

* Summe über drei Posten mit bekannten Preisen im gewählten Laden.
* Posten ohne Preis stehen in `ohne_preis` und **nicht** in der Summe.
* Offene (nicht abgehakte) Posten zählen nicht mit.
* Menge wird multipliziert; Menge `null` zählt als 1.
* Ein anderer Laden liefert eine andere Summe.
* Ohne `prices:read` → 403.
* Zweimal dieselbe Liste am selben Tag buchen → die zweite scheitert an
  `uq_buchung_fremdkennung`.

App: die Rechnung gehört wieder in eine reine Funktion, nicht in die
Seite — `finanz_rechnung.dart` oder ein Nachbar davon.

### Warum das mehr wert ist, als es aussieht

Es ist der einzige Weg, auf dem Ausgabedaten **entstehen, ohne dass
jemand sie tippt.** Alles andere im Tracker verlangt Disziplin; das hier
fällt beim Abhaken nebenbei an. Und es macht das Preisgedächtnis zum
zweiten Mal nützlich, ohne dass dafür etwas Neues gepflegt werden muss.

Die nächste Stufe derselben Idee ist der Bon-Scan (§10) — der liefert
statt einer Schätzung den **echten** Endbetrag. Diese Brücke ist die
billige Vorstufe, die schon ohne KI funktioniert.

---

## 8. Reihenfolge

Sieben PRs. **Jeder von `main` abzweigen**, nicht aufeinander stapeln —
wird der unterste gemergt, zeigen die darüber ins Leere.

| # | Repo | Inhalt | Danach benutzbar? | Stand |
|---|---|---|---|---|
| 1 | OwnAPI | Migration, Modelle, Rechte, Kassen + Kategorien + Buchungen, Tests | — | **PR #24** |
| 2 | OwnApp | Datenklassen, Dienst, Kassen- und Monatsseite, Route, Drawer, Rechte | **ja** — Buchen von Hand geht | |
| 3 | OwnAPI | Serien, Staffel, Vorschau, `nachbuchen`, Scheduler-Job, Tests | — | |
| 4 | OwnApp | Serienseite, Staffel-Editor, Vorschau in der Monatsansicht | **ja** — vollständig | |
| 5 | OwnApp | vier Kacheln, `FilterFields.finanzen`, `DashboardData` an drei Stellen | | |
| 6 | OwnAPI | Assistent: Werkzeuge + **neue** Aktions-`kind`s | | |
| 7 | beide | Brücke Einkaufsliste → Buchung (§7) | | |

Nach PR 4 ist das Projekt fachlich fertig. 5, 6 und 7 sind Zugaben.

**PR 7 hängt nur an 1 und 2**, nicht an den Serien. Er lässt sich also
vorziehen, sobald die App buchen kann — und sollte es vielleicht auch:
er ist der einzige Teil, bei dem Ausgabedaten entstehen, ohne dass sie
jemand tippt.

**Zu PR 6, weil das die Falle dieses Backends ist:** ein `kind` gehört
nicht dem Werkzeug, das es erzeugt. Die neuen Aktionen heißen
`add_booking`, `update_booking`, `remove_booking` — **niemals** ein
bestehendes `kind` umbiegen. Rechte werden zweimal geprüft, im Werkzeug
und in der Aktion: eine bestätigte Aktion kommt als roher Aufruf mit
`account_id` zurück und trägt ihre Berechtigung nicht mit.

Und wie bei den Einkaufslisten: gibt es mehrere Kassen und der Nutzer
nennt keine, **rückfragen statt raten**.

Für die Sprachsteuerung ist **keine neue Stufe** in
`SprachProvider._verarbeite()` nötig. „Trag zwölf Euro Edeka ein" geht
ans Sprachmodell und von dort ans Werkzeug. Ein eigener Parser dafür wäre
gierig und finge Sätze ab, die anderswo hingehören.

---

## 9. Ausrollen

Nichts Besonderes, aber in dieser Reihenfolge (siehe `SKILLS.md` beider
Repos):

**OwnAPI zuerst** — die App darf nie auf Endpunkte zeigen, die es noch
nicht gibt:

```bash
gh run watch <id> --exit-status
gh workflow run promote.yml -f tag=test -f grund="Finanzen: Kassen und Buchungen"
ssh ownserver 'cd ~/ownapi && ./deploy/update.sh prod'
```

Die Migrationszeilen in der Ausgabe **lesen**, nicht „läuft" annehmen:

```
api-1  | INFO __main__: Migration 031_finanzen.sql
```

Danach in der Datenbank nachsehen, ob die Kategorien wirklich drinstehen.

**Dann OwnApp** — mergen, Bau abwarten, Watchtower tauscht selbst. Und
dem Nutzer sagen, dass er **Cmd/Strg + Shift + R** drücken muss; ohne das
hält der Service Worker die alte Fassung fest und er meldet einen Fehler,
den es nicht gibt.

Die Migration ist rein additiv, also keine Rückfrage nötig.

---

## 10. Was bewusst draußen bleibt

| | Warum |
|---|---|
| **Bankanbindung** | Eigenes Vorhaben. Der Entwurf hält ihr mit `finance_accounts` und `external_uid` die Tür auf, mehr nicht. |
| **Budgets / Sparziele** | Erst wissen, wofür man Geld ausgibt, dann Grenzen ziehen. Sonst setzt man Grenzen ins Blaue. |
| **Buchung auf mehrere Kategorien aufteilen** | Ein Einkauf mit Lebensmitteln *und* Drogerie. Kommt regelmäßig vor, ist aber eine eigene Tabelle und eine eigene Oberfläche. Später. |
| **Belegfotos** | Braucht Dateiablage, die es im Backend noch nicht gibt. |
| **Brücke Bon-Scan → Buchung** | `receipt.py` liest den Kassenzettel schon und liefert den **echten** Betrag statt einer Schätzung. Die Stufe nach §7 — und erst, wenn die sich bewährt hat. |
| **Mehrere Währungen** | Nein. |

---

## 11. Die Zeile für ARCHITEKTUR.md

Wenn das hier gebaut ist, gibt es **zwei Wiederholungssysteme** im Haus,
und sie verhalten sich absichtlich verschieden. Das ist genau der
Doppelgänger, den `ARCHITEKTUR.md` auflisten soll — sonst nimmt der
nächste an, Finanzen funktionierten wie der Planer, und materialisiert
die Zukunft.

| | `planner_recurrences` | `finance_series` |
|---|---|---|
| Vorkommen | materialisiert, 183 Tage voraus | nur bis heute |
| Zukunft | echte Zeilen | gerechnet, nie gespeichert |
| Betrag/Inhalt | am Vorkommen | an der Staffel, nach Datum |
| Warum so | das Telefon muss ohne Server erinnern können | ein künftiger Betrag ist eine Erwartung, keine Tatsache |
| Gemeinsam | `freq` / `interval_n` / `byweekday` / `bymonthday`, `is_detached` | |

---

## 12. Offene Entscheidungen

Vor PR 1 zu klären:

1. **Startet v1 mit einer Kasse oder mit mehreren?** Der Entwurf kann
   beides; „Haushalt" als einzige Kasse beim ersten Start anzulegen wäre
   die freundlichere Vorgabe.
2. **Sollen Kategorien hierarchisch sein?** (`parent_id`) Der Entwurf
   lässt sie flach. Zwei Ebenen wären hübsch, kosten aber in jeder
   Auswertung und jedem Auswahlfeld.
3. **Wie weit reicht die Vorschau?** Vorschlag: bis Ende des
   übernächsten Monats in der Seite, frei wählbar in der Kachel.
4. **Soll eine Serie ein Fälligkeits-Hinweis werden?** Die
   Benachrichtigungen sind auf 58 vorgemerkte Meldungen gedeckelt
   (iOS-Grenze, 64). Eine neue Quelle muss durch
   `NotificationScheduler.rescheduleAll()` gehen, sonst kennt sie das
   Budget der anderen nicht. Eher nein für v1.

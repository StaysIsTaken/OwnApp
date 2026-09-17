# MCP.md — das nächste Projekt

Ein MCP-Zugang je Person: ein fremder Assistent (Claude, ein anderer
Client) darf die Daten dieser App lesen — aber nur die des angemeldeten
Nutzers, nur die Bereiche, die er selbst angehakt hat, und nur so weit,
wie seine Rolle es ohnehin erlaubt.

Diese Datei ist der Bauplan, nicht die Beschreibung eines fertigen
Bereichs. Ist er gebaut, wandert das Bleibende nach `ARCHITEKTUR.md`
(beide Repos) und `README.md`, und diese Datei kann weg. Vorbild und
Gegenstück: die beiden Pläne davor, `AUSGABEN-TRACKER.md` und
`HAUSHALTE.md` — beide gebaut, beide deshalb gelöscht.

**Der Löwenanteil liegt in OwnAPI.** Die App baut die Einstellungen, der
Server macht die Arbeit. Wer nur eine Hälfte liest, baut die andere
falsch.

**Enthalten, obwohl es nicht nach MCP klingt: die Zusammenlegung der
Benutzereinstellungen** (§3). Es gibt heute keine Tabelle für „was diese
Person eingestellt hat", und die MCP-Schalter brauchen eine. Also entsteht
sie hier — und nimmt gleich mit, was bisher am Gerät klebte.

---

## 1. Das Leitprinzip: alles aus

**Nichts verlässt diesen Server, bis jemand es einzeln anhakt.**

Das ist die Zeile, aus der alles Weitere folgt, und sie ist beim MCP
strenger zu nehmen als bei allem bisherigen: was hier hinausgeht, geht an
einen fremden Dienst und kommt nicht zurück.

```
Nichts eingestellt   →  kein MCP. Die Route gibt es nicht (404).
MCP angeschaltet     →  MCP läuft, gibt aber NICHTS heraus.
Bereich angehakt     →  dieser Bereich, nur lesend.
"auch schreiben"     →  anlegen und ändern. Löschen nie.
```

Vier Stufen, und jede einzelne muss bewusst umgelegt werden. Das ist
dasselbe Muster wie `finanz_sicht = nichts` bei den Haushalten: die
Vorgabe gibt nichts preis, und wer etwas freigibt, hat es getan und nicht
vergessen zu verhindern.

---

## 2. Die Entscheidungen

### 2.1 Der MCP wird in OwnAPI eingehängt, nicht danebengestellt

Ein eigener Dienst müsste die API über HTTP rufen und dabei ein zweites
Mal auslegen, wer was sehen darf. Dann gibt es zwei Stellen, die
„gehört mir" beantworten — genau der Doppelgänger, gegen den
`ARCHITEKTUR.md` geschrieben ist, und diesmal an der Stelle, an der ein
Fehler Daten herausgibt statt eine Seite kaputtzumachen.

Eingehängt hat er `haushalt_service.sichtbarkeit()`, `hat_recht()` und
alle Dienste direkt. Kein neues Repository, kein zweites Bild, kein
zweites Ausrollen.

### 2.2 Die Route adressiert, der Schlüssel meldet an

```
https://<server>/mcp/<slug>        Authorization: Bearer mcp_<schluessel>
```

**Die Route allein darf nichts freigeben.** Eine URL ist kein Passwort:
sie steht im Server-Log, im Proxy-Log, in der Konfigurationsdatei des
Clients im Klartext und auf jedem Screenshot der Einrichtung. Wer den
Slug hat, hat deshalb noch nichts.

Warum es den Slug trotzdem gibt: der Nutzer sieht in seiner
Client-Konfiguration, wessen Zugang das ist; ein abgeschalteter MCP ist
ein **404** statt einer Prüfung im Inneren; und Rate-Limit und Protokoll
hängen sauber an der Route. Der Slug ist zufällig und **nicht** die
Benutzer-ID — er landet in Konfigurationsdateien, und eine ID, die
anderswo etwas bedeutet, gehört dort nicht hin.

### 2.3 Der Schlüssel wird gehasht, nicht verschlüsselt

Das Haus kann beides: Passwörter liegen als bcrypt-Hash, API-Schlüssel
fremder KI-Anbieter liegen mit Fernet **verschlüsselt** und lassen sich
wieder anzeigen (`ai_settings_service._decrypt`).

Hier gilt der Hash, und der Grund steht in `SKILLS.md`: **`update.sh`
zieht bei jedem Ausrollen einen Abzug.** Ein wiederanzeigbarer Schlüssel
liegt dann in jedem dieser Abzüge im Klartext, und die liegen herum. Ein
Hash in einem Abzug ist wertlos.

Der Preis ist, dass man den Schlüssel nur **einmal** sieht. Das ist
tragbar, weil Erneuern ein Knopfdruck ist — und Erneuern ist ohnehin das,
was man nach einem Versehen braucht, nicht Nachschlagen.

**Gehasht wird mit SHA-256, nicht mit bcrypt.** Bcrypt ist absichtlich
langsam; das ist bei einem Passwort richtig und bei einem Schlüssel, der
bei **jeder** Anfrage geprüft wird, ein Selbsttor — es kostet hundert
Millisekunden pro Aufruf und macht den Endpunkt selbst zur Angriffsfläche.
Ein Schlüssel aus 32 zufälligen Bytes braucht keine Streckung: gegen
Raten hilft seine Länge, gegen Wörterbücher gibt es nichts zu raten.

### 2.4 Ein Schlüssel je Person

Nicht einer je Client. Das hält die Einstellungen in **einer** Zeile
(§3) und die Oberfläche bei einem Knopf.

Wer später einzelne Clients getrennt sperren will, braucht eine eigene
Tabelle mit einer Zeile je Schlüssel. Dann wandert `token_hash` dorthin;
alles andere bleibt, wo es ist. Die Entscheidung ist also umkehrbar —
aber sie gehört nicht in die erste Runde.

### 2.5 Schreiben heißt anlegen und ändern, niemals löschen

Im MCP gibt es kein Werkzeug, das etwas löscht. Nicht abschaltbar,
sondern gar nicht vorhanden.

Der Grund ist die fehlende Bestätigungskarte. In der App schlägt der
Assistent vor und der Nutzer tippt „ja" — über MCP entscheidet der fremde
Client, ob er fragt, und ein Text in einer Notiz kann ihn dazu überreden,
etwas zu tun, das niemand wollte. Alles andere lässt sich zurücknehmen;
ein Löschen nicht.

### 2.6 Der Chat kommt nicht vor — auch nicht als ausgeschalteter Schalter

In jedem anderen Bereich stehen deine Daten. Im Chat stehen die
Nachrichten **anderer Leute**, und deine Zustimmung reicht dafür nicht.

Ein Schalter, den man umlegen könnte, ist eine Einladung, ihn umzulegen.
Deshalb gibt es ihn nicht: kein Werkzeug, kein Eintrag im Baum, keine
Zeile in der Tabelle.

### 2.7 Die Schalter können nur wegnehmen

Wirksam ist **Rolle ∩ Baum**. Wer „Finanzen" anhakt, aber `finance:read`
nicht hat, bekommt nichts — und merkt es an einer leeren Antwort, nicht
an einem Fehler, der verrät, dass es dort etwas gäbe.

Das ist die Umkehrung der Menü-Regel aus `SKILLS.md`: ein ausgeblendeter
Menüpunkt ist Höflichkeit, dieser Schalter ist eine echte Schranke,
serverseitig geprüft. Beides muss nebeneinander stehen, sonst baut es
jemand als Anzeige.

---

## 3. Datenmodell

### 3.1 Migration `app/db/sql/034_benutzereinstellungen.sql`

Nächste freie Nummer nach `033_essensplan_besitzer.sql`.

**Sie teilt sich auf drei auf**, entlang der Reihenfolge in §11 — eine
Migration, die Spalten für einen Endpunkt anlegt, den es erst in drei PRs
gibt, wäre eine Migration ohne Leser:

| | Inhalt | PR | additiv? |
|---|---|---|---|
| `034_benutzereinstellungen.sql` | `user_settings` + eine Zeile je Nutzer | 1 | **ja** |
| `035_mcp_haushalt.sql` | `mcp_freigabe`, `created_by`, Übernahme des Altbestands | 5 | **nein** |
| `036_mcp_protokoll.sql` | `mcp_zugriffe` | 8 | ja |

**Nur die mittlere ist nicht rein additiv** — sie ordnet Bestandsdaten
zu. Nach `OwnAPI/SKILLS.md` §1 ist das der Fall zum vorher fragen, und die
Zählabfrage aus §3.2 gehört dorthin. 034 und 036 legen nur an.

Vorher zu klären ist auch, ob `user_ai_settings` mitgelöscht wird:
Migration 010 hat ihren Inhalt nach `ai_providers` umgezogen, und
seitdem liest sie **niemand** — sie steht nur noch in `session.py`, damit
das Modell registriert wird. Der Plan lässt sie stehen; wegräumen ist
eine eigene, ehrliche Zeile und nicht etwas, das man nebenbei mitnimmt.

```sql
-- Benutzereinstellungen: eine Zeile je Person, alles Uebergreifende.
--
-- WARUM EINE ZEILE UND NICHT EINE TABELLE JE THEMA:
-- Diese Werte werden bei praktisch jeder Anfrage gebraucht (der MCP
-- fragt sie bei JEDEM Aufruf) und aendern sich fast nie. Ein Join je
-- Bereich waere Arbeit fuer nichts.
--
-- WARUM SPALTEN UND KEIN JSON:
-- JSON ist der Ort, an dem Einstellungen verrotten -- nicht typisiert,
-- nicht im Schema sichtbar, nicht abfragbar, und ein Tippfehler faellt
-- erst auf, wenn jemand die Einstellung sucht. Ein neuer MCP-Bereich
-- kostet hier eine Migration. Das ist der Preis, und er ist richtig
-- herum: eine Spalte mehr ist sichtbar, ein Schluessel mehr in einem
-- Klumpen nicht.
--
-- WAS HIER NICHT HINEINGEHOERT:
-- Was am GERAET haengt und nicht an der Person. Das Weckwort und seine
-- Schwelle bleiben in den SharedPreferences -- gelauscht wird in der
-- Kueche, nicht auf dem Telefon in der Hosentasche, und die Schwelle
-- haengt am Raum. Der Hell-/Dunkelmodus bleibt ebenfalls am Geraet: das
-- Kuechentablet an der Wand will tagsueber hell und das Telefon dunkel.

CREATE TABLE IF NOT EXISTS user_settings (
  user_id VARCHAR(36) NOT NULL,

  -- ── Allgemein (kommt aus den SharedPreferences der App) ─────────────
  use_24h TINYINT(1) NOT NULL DEFAULT 1,
  weather_city VARCHAR(80) NULL,

  -- ── KI (heute doppelt: hier und am Geraet) ──────────────────────────
  -- Die Journal-Analyse las die Geraetefassung, der Assistent die vom
  -- Server. Wer die Temperatur verstellte, aenderte je nach Geraet
  -- etwas anderes.
  ai_model VARCHAR(120) NULL,
  ai_temperature FLOAT NULL,
  ai_max_tokens INT NULL,

  -- ── MCP: der Stamm des Baums ────────────────────────────────────────
  -- Aus als Vorgabe. Ein MCP entsteht erst, wenn jemand ihn anschaltet,
  -- und gibt dann immer noch nichts heraus.
  mcp_an TINYINT(1) NOT NULL DEFAULT 0,
  mcp_slug VARCHAR(32) NULL,
  -- SHA-256 des Schluessels, hex. Siehe 2.3 -- kein bcrypt, das laeuft
  -- bei jeder Anfrage.
  mcp_token_hash CHAR(64) NULL,
  mcp_token_erstellt_at DATETIME NULL,
  mcp_zuletzt_benutzt_at DATETIME NULL,

  -- ── MCP: die eigenen Bereiche (Ebene 2), je lesen und schreiben ─────
  mcp_rezepte TINYINT(1) NOT NULL DEFAULT 0,
  mcp_rezepte_w TINYINT(1) NOT NULL DEFAULT 0,
  mcp_vorrat TINYINT(1) NOT NULL DEFAULT 0,
  mcp_vorrat_w TINYINT(1) NOT NULL DEFAULT 0,
  mcp_einkauf TINYINT(1) NOT NULL DEFAULT 0,
  mcp_einkauf_w TINYINT(1) NOT NULL DEFAULT 0,
  mcp_essensplan TINYINT(1) NOT NULL DEFAULT 0,
  mcp_essensplan_w TINYINT(1) NOT NULL DEFAULT 0,
  mcp_termine TINYINT(1) NOT NULL DEFAULT 0,
  mcp_termine_w TINYINT(1) NOT NULL DEFAULT 0,
  mcp_aufgaben TINYINT(1) NOT NULL DEFAULT 0,
  mcp_aufgaben_w TINYINT(1) NOT NULL DEFAULT 0,
  mcp_notizen TINYINT(1) NOT NULL DEFAULT 0,
  mcp_notizen_w TINYINT(1) NOT NULL DEFAULT 0,
  mcp_zeiten TINYINT(1) NOT NULL DEFAULT 0,
  mcp_zeiten_w TINYINT(1) NOT NULL DEFAULT 0,
  mcp_preise TINYINT(1) NOT NULL DEFAULT 0,
  mcp_preise_w TINYINT(1) NOT NULL DEFAULT 0,
  mcp_finanzen TINYINT(1) NOT NULL DEFAULT 0,
  mcp_finanzen_w TINYINT(1) NOT NULL DEFAULT 0,
  mcp_journal TINYINT(1) NOT NULL DEFAULT 0,
  mcp_journal_w TINYINT(1) NOT NULL DEFAULT 0,

  -- ── MCP: der Haushalt als eigener Ast (Ebene 2 und 3) ───────────────
  -- Erst dieser Schalter, dann die einzelnen gemeinsamen Bereiche.
  -- Beides aus als Vorgabe, auch fuer den, der schon im Haushalt ist.
  mcp_haushalt TINYINT(1) NOT NULL DEFAULT 0,
  mcp_h_rezepte TINYINT(1) NOT NULL DEFAULT 0,
  mcp_h_rezepte_w TINYINT(1) NOT NULL DEFAULT 0,
  mcp_h_vorrat TINYINT(1) NOT NULL DEFAULT 0,
  mcp_h_vorrat_w TINYINT(1) NOT NULL DEFAULT 0,
  mcp_h_einkauf TINYINT(1) NOT NULL DEFAULT 0,
  mcp_h_einkauf_w TINYINT(1) NOT NULL DEFAULT 0,
  mcp_h_essensplan TINYINT(1) NOT NULL DEFAULT 0,
  mcp_h_essensplan_w TINYINT(1) NOT NULL DEFAULT 0,
  mcp_h_preise TINYINT(1) NOT NULL DEFAULT 0,
  mcp_h_preise_w TINYINT(1) NOT NULL DEFAULT 0,
  mcp_h_finanzen TINYINT(1) NOT NULL DEFAULT 0,
  mcp_h_finanzen_w TINYINT(1) NOT NULL DEFAULT 0,

  updated_at DATETIME NULL,
  PRIMARY KEY (user_id),
  UNIQUE KEY uq_mcp_slug (mcp_slug),
  CONSTRAINT fk_user_settings_user
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) COLLATE=utf8mb4_general_ci;

-- Die Freigabe des Mitglieds: "meine Beitraege duerfen in die MCPs
-- dieses Haushalts". Sie gehoert an die MITGLIEDSCHAFT und nicht an den
-- Nutzer -- sie gilt diesem Haushalt und endet mit ihm. Wer austritt und
-- anderswo beitritt, faengt wieder bei nein an.
--
-- Vorgabe 0, auch fuer die, die heute schon drin sind. Eine Migration
-- ist kein Einverstaendnis -- dieselbe Zeile stand schon bei
-- finanz_sicht.
ALTER TABLE household_members
  ADD COLUMN mcp_freigabe TINYINT(1) NOT NULL DEFAULT 0;

-- Wer hat diese Position geschrieben? Bisher niemand -- eine gemeinsame
-- Einkaufsliste gehoert dem Haushalt, ihre Posten aber niemandem.
--
-- Ohne diese Spalte laesst sich "Daten von Mitgliedern ohne Freigabe
-- gehen nicht hinaus" auf der gemeinsamen Liste nicht einhalten: "Milch"
-- von B ist dort von "Milch" von A nicht zu unterscheiden.
ALTER TABLE shopping_positions
  ADD COLUMN created_by VARCHAR(36) NULL,
  ADD KEY idx_position_ersteller (created_by),
  ADD CONSTRAINT fk_position_ersteller
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE article_prices
  ADD COLUMN created_by VARCHAR(36) NULL,
  ADD KEY idx_preis_ersteller (created_by),
  ADD CONSTRAINT fk_preis_ersteller
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;

-- Was herausgegeben wurde. Ohne das kann nach einem verlorenen
-- Schluessel niemand sagen, was abgeflossen ist -- und genau danach
-- fragt man dann als Erstes.
CREATE TABLE IF NOT EXISTS mcp_zugriffe (
  id BIGINT NOT NULL AUTO_INCREMENT,
  user_id VARCHAR(36) NOT NULL,
  werkzeug VARCHAR(60) NOT NULL,
  anzahl INT NOT NULL DEFAULT 0,
  erfolg TINYINT(1) NOT NULL DEFAULT 1,
  ip VARCHAR(45) NULL,
  at DATETIME NOT NULL,
  PRIMARY KEY (id),
  KEY idx_zugriff_person_zeit (user_id, at),
  CONSTRAINT fk_zugriff_person
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) COLLATE=utf8mb4_general_ci;
```

**Beim Schreiben der Datei beachten:** `migrate.py` wirft Kommentarzeilen
raus und zerlegt an `;`. Kein Semikolon in einen Kommentar setzen, der
stehenbleiben soll, und keine mehrzeiligen `/* */`-Kommentare.

### 3.2 Übernahme der Bestandsdaten

```sql
-- Eine Zeile je Nutzer, alles auf Vorgabe. Ohne diese Zeile muesste
-- jede Abfrage den Fall "gibt es noch nicht" behandeln.
INSERT INTO user_settings (user_id, updated_at)
  SELECT id, NOW() FROM users;

-- Die App hat diese App bisher allein benutzt: was keinen Besitzer hat,
-- gehoert dem Verwalter. Ohne das waere jede alte Position "von
-- niemandem" und damit fuer immer aus dem MCP ausgeschlossen.
UPDATE shopping_positions SET created_by =
  (SELECT id FROM users ORDER BY created_at LIMIT 1)
  WHERE created_by IS NULL;

UPDATE article_prices SET created_by =
  (SELECT id FROM users ORDER BY created_at LIMIT 1)
  WHERE created_by IS NULL;
```

> **Vor dem Ausrollen zählen.** Der Altbestand — `owner_id` **und**
> `household_id` leer — ist heute für jeden mit dem Recht sichtbar
> (`haushalt_service.py`, „Altbestand"). Bekäme er einen Besitzer,
> verschwände er für alle anderen aus der App. Migration 032 hat Rezepte,
> Vorrat, Preise und Essensplan schon einem Haushalt zugeordnet, also
> sollte die Antwort überall 0 sein — aber geprüft wird es, nicht
> angenommen:
>
> ```sql
> SELECT 'Recipe', COUNT(*) FROM Recipe
>   WHERE owner_id IS NULL AND household_id IS NULL
> UNION ALL SELECT 'PantryItem', COUNT(*) FROM PantryItem
>   WHERE owner_id IS NULL AND household_id IS NULL
> UNION ALL SELECT 'MealPlanEntry', COUNT(*) FROM MealPlanEntry
>   WHERE owner_id IS NULL AND household_id IS NULL;
> ```
>
> Steht dort irgendwo etwas anderes als 0, wird erst geredet und dann
> migriert.

---

## 4. Die Anmeldung

### 4.1 Der Ablauf

```
In der App, einmal                     Bei jedem Aufruf
──────────────────                     ────────────────
Einstellungen → Assistent-Zugang       GET/POST /mcp/k7f3x9q2
  [x] MCP aktivieren                   Authorization: Bearer mcp_a8Fk...
        ↓                                       ↓
Server erzeugt                         sha256(schluessel) → Zeile finden
  slug   k7f3x9q2                      → Nutzer steht fest
  token  mcp_a8Fk…  (einmal sichtbar)  → Rolle: rechte_des_nutzers()
  hash   in user_settings              → Baum: user_settings
        ↓                              → Schnittmenge = was herausgeht
Nutzer traegt beides in den Client     → zuletzt_benutzt_at setzen
```

Der Slug steht in der Route **und** die Zeile ist über den Hash
auffindbar. Geprüft wird beides und es muss dieselbe Zeile sein — sonst
könnte ein gültiger Schlüssel an einer fremden Route Daten holen, und die
Route wäre eine Dekoration.

### 4.2 Was die App dauerhaft zeigt

```
Assistent-Zugang                                     [ aktiv ]

  Adresse    https://<server>/mcp/k7f3x9q2            [kopieren]
  Schlüssel  mcp_a8Fk••••••••••••••••••     angelegt 17.09.2026
             zuletzt benutzt: heute, 08:14
                                        [ Neuen Schlüssel erzeugen ]
```

Der ganze Schlüssel steht **genau einmal** da, direkt nach dem Erzeugen,
mit Kopierknopf und dem Satz, dass er danach nicht mehr zu sehen ist.
Danach nur noch sein Anfang — damit man wiedererkennt, welcher wo
eingetragen ist.

„Zuletzt benutzt" ist nicht Zierde: daran sieht man, dass jemand den
Zugang benutzt, den man selbst gerade nicht benutzt.

**Erneuern macht den alten sofort ungültig.** Kein Übergangsfenster —
sonst ist es keine Sperre, sondern eine Bitte. Die App sagt es vorher:
„Der bisherige Schlüssel hört sofort auf zu gelten. Du musst ihn überall
neu eintragen."

### 4.3 Warum `require()` hier nicht funktioniert

Das ist die Falle beim Bauen. `require(...)` hängt an `get_current_user`,
und das entschlüsselt ein **JWT** — ein MCP-Schlüssel ist keins, und der
Aufruf endete in „Ungültiger Token".

Der MCP braucht deshalb eine eigene Abhängigkeit:

```python
def mcp_nutzer(slug: str, authorization: str = Header(...)) -> McpKontext
    # -> Nutzer, Rechte (rechte_des_nutzers), Einstellungen (eine Zeile)
```

Wiederverwendet wird alles **darunter**: `rechte_des_nutzers()`,
`hat_recht()`, `haushalt_service.sichtbarkeit()`, die Dienste. Nur die
Tür ist eine andere. Ein Vorbild dafür gibt es schon:
`require_service_token` in `dependencies.py` ist genau so ein zweiter
Eingang, nur ohne Nutzer dahinter.

---

## 5. Was im MCP liegt

| Bereich | lesen | schreiben möglich? | Recht |
|---|---|---|---|
| Rezepte | ja | anlegen, ändern | `recipes:read` / `:write` |
| Vorrat | ja | anlegen, ändern | `pantry:read` / `:write` |
| Einkaufslisten | ja | Position anlegen, abhaken | `shopping:read` / `:write` |
| Essensplan | ja | Eintrag anlegen | `mealplan:read` / `:write` |
| Termine | ja | Termin anlegen, ändern | `planner:read` / `:write` |
| Aufgaben | ja | anlegen, verschieben, abhaken | `tasks:read` / `:write` |
| Notizen | ja | anlegen, ändern | `notes:read` / `:write` |
| Zeiterfassung | ja | Eintrag anlegen, beenden | `time:read` / `:write` |
| Preise | ja | Preis merken | `prices:read` / `:write` |
| Finanzen | ja | Buchung anlegen, ändern | `finance:read` / `:write` |
| Journal | ja | Eintrag anlegen | `journal:read` / `:write` |
| **Chat** | **nein** | — | kommt nicht vor, §2.6 |
| **Verwaltung, Rollen, Stimmprofile** | **nein** | — | s. u. |

**Verwaltung gibt es nicht im MCP, unter keinem Schalter.** Was Rollen
vergeben, Passwörter zurücksetzen oder Nutzer löschen kann, darf nicht
an einem Ende hängen, an dem ein fremdes Sprachmodell entscheidet, was
aufgerufen wird. Dasselbe gilt für die Stimmprofile: die sind biometrisch.

Die Liste der Bereiche steht seit PR 1 an **einer** Stelle im Code:
`MCP_BEREICHE` und `MCP_HAUSHALT_BEREICHE` in
`app/models/user_settings.py`. Wer einen Bereich ergänzt, ergänzt ihn
dort — sonst pflegen Dienst, Schema und Tests je eine eigene Liste, und
die dritte vergisst jemand.

`finance:read_all`, `planner:read_all` und `shopping:read_all` werden im
MCP **ignoriert**. Der Zugang gibt heraus, was *dir* gehört, nicht was du
im Haushalt sehen dürftest — dafür ist der Haushalts-Ast da, und der
fragt zusätzlich die Mitglieder (§6).

---

## 6. Der Haushalt

Zwei Tore, und beide müssen offen sein.

```
Haushaltseinstellungen  →  jedes Mitglied hakt für sich an:
  (household_members)      "meine Beiträge dürfen in die MCPs
   mcp_freigabe             dieses Haushalts"
                                     ↓
Benutzereinstellungen   →  [ ] Haushalt im MCP          ← aus
  (user_settings)            └ [ ] unsere Einkaufsliste ← aus
   mcp_haushalt                   └ [ ] auch schreiben  ← aus
```

Das Mitglied gibt seine Beiträge frei — und **du** entscheidest trotzdem
noch, ob dein Zugang sie überhaupt herausgibt. Das eine ersetzt das
andere nicht: die Freigabe sagt „von mir aus", der Baum sagt „ich will".

### 6.1 Gefiltert wird je Objekt, über den Ersteller

Haushaltsobjekte behalten beim Verschieben ihren `owner_id`
(`haushalt_service.besitz_beim_anlegen`), Positionen und Preise bekommen
mit Migration 034 ein `created_by`. Damit gilt überall dieselbe Regel:

> Ein gemeinsames Objekt geht nur hinaus, wenn **sein Ersteller**
> `mcp_freigabe` gesetzt hat.

Kein Alles-oder-nichts, kein Herausrechnen fremder Beiträge aus einer
Summe — es fällt einfach weg, was nicht freigegeben ist.

### 6.2 Und es wird gesagt, was fehlt

Wie bei den Finanzen: eine Liste, aus der die Hälfte stillschweigend
fehlt, ist schlimmer als eine, die sagt, dass sie unvollständig ist. Jede
Antwort mit gefilterten Haushaltsdaten trägt deshalb einen Hinweis:

```json
{"posten": [...], "ausgelassen": 3,
 "hinweis": "3 Einträge von Mitgliedern ohne MCP-Freigabe fehlen."}
```

Derselbe Gedanke wie `ohne_preis`, `ohne_zutat` und „2 von 3 Mitglieder
rechnen mit". Ein Assistent, der nicht weiß, dass etwas fehlt, behauptet
sonst, der Zettel sei leer.

### 6.3 Auf der Haushaltsseite steht, wer freigegeben hat

Nicht versteckt. Wer gemeinsame Daten an einen fremden Assistenten
weitergibt, tut das mit den Beiträgen der anderen — die dürfen es sehen,
so wie sie sehen, wer bei den Finanzen mitrechnet.

---

## 7. Der Baum in der App

`Einstellungen → Assistent-Zugang`. Jede Ebene klappt erst auf, wenn die
darüber an ist:

```
[✓] MCP aktivieren
     │
     ├ [✓] Rezepte
     │      └ [ ] auch schreiben
     ├ [ ] Vorrat
     ├ [ ] Notizen
     ├ [ ] Finanzen          ← Hinweis: Kontostände und Buchungen
     ├ [ ] Journal           ← Hinweis: der privateste Text der App
     │
     └ [✓] Haushalt
            ├ [✓] unsere Einkaufsliste
            │      └ [ ] auch schreiben
            └ [ ] unsere Rezepte
```

Drei Regeln, die dazugehören:

**Ausschalten löscht, was darunter stand.** Sonst schaltet jemand
Finanzen an, erlaubt Schreiben, schaltet Finanzen aus — und Monate später
wieder an, und das Schreiben ist still wieder da. Was angeht, geht mit
allem darunter **aus** an.

**Der Haushalts-Ast erscheint nur, wenn es einen Haushalt gibt.** Sonst
steht dort ein Ast über etwas, das es nicht gibt — dieselbe Regel wie
`Haushaltssicht.zeigtUmschaltung()`, und sie gehört in dieselbe Datei.

**Der Server prüft die Kette trotzdem.** Wirksam ist
`mcp_an ∧ Bereich ∧ Schreiben ∧ Recht`, bei Haushaltsdaten zusätzlich
`mcp_haushalt ∧ Bereich ∧ Freigabe des Erstellers`. Die Oberfläche ist
Bedienung, nicht Absicherung.

Testbar wird das, indem die Kette eine **reine Funktion** wird —
derselbe Kunstgriff wie `haushalt_sicht.dart` und `finanz_rechnung.dart`:

```dart
McpBaum.zeigtEbene(...)     // klappt hier etwas auf?
McpBaum.wirksam(...)        // darf dieser Bereich, dieses Schreiben?
McpBaum.beimAusschalten(...) // was wird mit zurückgesetzt?
```

---

## 8. Rate-Limit und Protokoll

Zwei Grenzen, und sie schützen Verschiedenes:

| | Grenze | wogegen |
|---|---|---|
| **angemeldet** | 60 Aufrufe/Minute je Schlüssel | ein Client, der Amok läuft |
| **fehlgeschlagen** | 10/Minute je IP **und** je Slug, danach Verzögerung | das Durchprobieren von Schlüsseln |

Die zweite ist die wichtigere. Ohne sie nützt ein langer Schlüssel wenig,
weil jemand ihn Tag und Nacht raten darf.

Gezählt wird im Speicher des Prozesses, nicht in der Datenbank — bei
mehreren Arbeitern zählt jeder seine eigenen, und das ist hier in
Ordnung: die Grenze soll bremsen, nicht buchhalten.

**Und: ein Fehlschlag sagt nichts.** Falscher Slug, falscher Schlüssel,
MCP ausgeschaltet — alles derselbe **404**. Ein 403 an einer Stelle
verriete, dass es diesen Zugang gibt.

Das Protokoll (`mcp_zugriffe`) hält fest, welches Werkzeug wann wie viele
Datensätze herausgegeben hat. In der App ist es die Zeile „zuletzt
benutzt"; vollständig gelesen wird es auf dem Server.

---

## 9. Backend-Arbeit

```
app/models/user_settings.py          eine Klasse
app/schemas/einstellungen.py
app/services/einstellungs_service.py  Zeile holen/anlegen, Baum setzen
app/services/mcp/
    __init__.py
    auth.py                          Slug + Schluessel -> McpKontext
    baum.py                          die Kette, als reine Rechnung
    werkzeuge.py                     die Werkzeuge je Bereich
    haushalt.py                      Filter ueber created_by/owner_id
app/api/endpoints/einstellungen.py   /einstellungen (JWT, fuer die App)
app/api/endpoints/mcp.py             /mcp/{slug}   (Schluessel, fuer Clients)
app/db/sql/034_benutzereinstellungen.sql
```

Der MCP-Router wird **nicht** unter `/api` eingehängt, sondern daneben:
`/api` trägt CORS-Regeln und die JWT-Anmeldung, und ein MCP-Client ist
kein Browser. In `main.py` also neben `app.include_router(router,
prefix="/api")`.

### 9.1 Werkzeuge: ohne `kind`, direkt in die Dienste

Der Assistent trennt Werkzeug und Aktion, weil der Nutzer dazwischen
bestätigt. **Diese Zwischenstufe gibt es im MCP nicht** — ein
Schreib-Werkzeug ruft den Dienst und ist fertig.

Deshalb entsteht hier **kein** neues `kind` und wird keins der
vorhandenen benutzt. `ARCHITEKTUR.md` §2 in OwnAPI sagt, warum das
wichtig ist: ein `kind`, das niemand ausführt, ist schlimmer als keins,
und ein `kind` umzubiegen ändert stillschweigend andere Erzeuger mit.

Die **Namen** dürfen sich beim Assistenten bedienen (`add_shopping_item`
heißt dort seit jeher so, obwohl die Tabelle darunter wechselte) — das
Vokabular ist erprobt, und ein zweites erfände nur Verwirrung.

---

## 10. Tests

Backend:

* Ohne Zeile in `user_settings` gibt es keinen MCP — 404.
* MCP an, alle Bereiche aus: jedes Werkzeug antwortet leer, keins mit 403.
* Ein Bereich an, Recht fehlt: leer. **Die Gegenprobe dazu**: Recht da,
  Schalter aus → ebenfalls leer.
* Schreiben aus: das Schreib-Werkzeug existiert nicht in der Liste.
* Es gibt **kein** Werkzeug, das löscht — über die Werkzeugliste geprüft,
  nicht über die Namen, die jemand gerade kennt.
* Falscher Schlüssel, falscher Slug, abgeschalteter MCP: dreimal 404 mit
  demselben Text.
* Gültiger Schlüssel an fremdem Slug: 404.
* Erneuern macht den alten Schlüssel sofort ungültig.
* Haushalt: Objekt eines Mitglieds **ohne** Freigabe fehlt — und die
  Antwort meldet, wie viele fehlen.
* Haushalt aus, aber Mitglied hat freigegeben: trotzdem nichts.
* `mcp_zugriffe` bekommt je Aufruf eine Zeile, auch bei Fehlschlag.
* Rate-Limit greift und gibt 429.

App: `McpBaum` als reine Funktion — Ebenen, Wirksamkeit, und dass
Ausschalten den Unterbaum zurücksetzt.

Zu jedem Test die Gegenprobe: kaputt machen, rot sehen, wiederherstellen.

---

## 11. Reihenfolge

Die Spalte **Stand** wird beim Arbeiten gepflegt: offen → die PR-Nummer,
sobald einer aufgemacht ist → ✅, sobald er in `main` steht. So sagt der
Plan jederzeit, wo er steht, und niemand muss es aus der Git-Historie
zusammensuchen.

| # | Repo | Inhalt | Basis | Danach benutzbar? | Stand |
|---|---|---|---|---|---|
| 1 | OwnAPI | Migration 034, `user_settings`, Dienst, `/einstellungen` | `main` | — | **#34** |
| 2 | OwnApp | Einstellungen lesen/schreiben, die drei Werte vom Gerät holen | PR 1 | **ja** — Einstellungen liegen am Konto | **#101** |
| 3 | OwnAPI | MCP: Anmeldung, Baum, Lese-Werkzeuge der eigenen Bereiche | PR 1 | | **#35** |
| 4 | OwnApp | der Baum in den Einstellungen, Schlüssel anzeigen/erneuern | PR 2+3 | **ja** — der MCP läuft | **#102** |
| 5 | OwnAPI | Haushalts-Ast: `mcp_freigabe`, Filter, „ausgelassen" | PR 3 | | **#36**, Migration nachgebessert in **#37** |
| 6 | OwnApp | Freigabe auf der Haushaltsseite, Haushalts-Ast im Baum | PR 4+5 | **ja** — vollständig | ⬜ |
| 7 | OwnAPI | Schreib-Werkzeuge | PR 3 | | ⬜ |
| 8 | OwnAPI | Rate-Limit, Protokoll | PR 3 | | ⬜ |

Nach PR 6 ist das Projekt fachlich fertig; 7 und 8 sind die Zugaben —
wobei **8 vor dem ersten öffentlichen Ausrollen stehen muss**. Ein
Zugang ohne Bremse für fehlgeschlagene Anmeldungen gehört nicht ins Netz.

Zum Stapeln gilt `SKILLS.md` §7 in beiden Repos: erst alle Kinder
umhängen, dann mergen; ein Basiswechsel löst keine CI aus; ohne Basis
`main` läuft gar nichts, und kein Häkchen heißt nicht grün.

---

## 12. Ausrollen

**OwnAPI zuerst**, wie immer — die App darf nie auf Endpunkte zeigen, die
es noch nicht gibt. Die Migrationszeile in der Ausgabe lesen, nicht
„läuft" annehmen:

```
api-1  | INFO __main__: Migration 034_benutzereinstellungen.sql
```

Danach in der Datenbank nachsehen, ob jeder Nutzer eine Zeile hat und ob
`mcp_an` überall 0 ist. Steht dort irgendwo eine 1, ist etwas mit den
Vorgaben schiefgegangen, und das ist der Fall, bei dem man sofort
zurückgeht.

**Die Migration ist nicht rein additiv** (§3.1) — also vorher fragen. Der
Abzug von `update.sh` ist die einzige Rückfahrkarte.

**Dann OwnApp**, und dem Nutzer sagen, dass er **Cmd/Strg + Shift + R**
drücken muss.

---

## 13. Was bewusst draußen bleibt

| | Warum |
|---|---|
| **Chat** | Fremde Nachrichten. Deine Zustimmung reicht dafür nicht — §2.6. |
| **Verwaltung, Rollen, Stimmprofile** | Was Rechte vergeben kann, darf nicht an einem Ende hängen, an dem ein Sprachmodell entscheidet. |
| **Löschen, egal wo** | Der einzige Fehler, den man von außen nicht zurücknehmen kann, und es gibt keine Bestätigungskarte. |
| **Mehrere Schlüssel je Person** | Erst wenn es zwei Clients gibt, die sich getrennt sperren lassen müssen. Das Datenmodell lässt es offen (§2.4). |
| **OAuth statt Schlüssel** | Die MCP-Spezifikation kann es; hier wäre es ein Anmeldeserver für einen einzigen Nutzerkreis. Der Schlüssel tut dasselbe mit einem Hundertstel des Aufbaus — **aber er kostet etwas, und das steht inzwischen in §15**. |
| **Ein MCP für den Haushalt** (statt je Person) | Klingt praktisch und ist die Rückkehr zu „alle sehen alles". Der Haushalts-Ast löst denselben Fall, ohne die Freigabe des Einzelnen zu übergehen. |
| **Werkzeuge, die rechnen** („wie viel gebe ich für X aus") | Der Client hat ein Sprachmodell, das rechnen kann, sobald es die Zahlen hat. Eine Auswertung im MCP wäre eine zweite Wahrheit neben `/finanzen/auswertung`. |

---

## 14. Die Zeilen für ARCHITEKTUR.md

Wenn das steht, gibt es **zwei Eingänge** in dieses Backend, und der
nächste Leser muss wissen, welcher wo gilt:

| | `/api/…` | `/mcp/{slug}` |
|---|---|---|
| Anmeldung | JWT, 60 Minuten, `get_current_user` | Schlüssel, unbegrenzt, `mcp_nutzer` |
| Rechteprüfung | `Depends(require(...))` | `hat_recht()` von Hand, **plus** der Baum |
| Wer ruft | die App | ein fremder Assistent |
| Bestätigung durch den Nutzer | in der App | **keine** — deshalb kein Löschen |

Dazu der Satz, der das Ganze trägt und den man sonst nicht
rekonstruieren kann:

> **Der MCP gibt nichts heraus, was nicht zweimal erlaubt wurde:
> von der Rolle und vom Nutzer.**

---

## 15. Die Clients — und was der Schlüssel kostet

Dieser Abschnitt entstand, nachdem der Zugang lief und niemand ihn
eintragen konnte.

**Nur ein Client nimmt heute einen eigenen Schlüssel entgegen.**

| Client | Schlüssel? | Wie |
|---|---|---|
| **Claude Code** | **ja** | `claude mcp add --transport http … --header "Authorization: Bearer …"` |
| **Claude Desktop** | **ja** | nicht über „Connectors", sondern über `claude_desktop_config.json` und **`mcp-remote`** |
| claude.ai im Browser | nein | nur Adresse + optional OAuth. Kein Header, und im Browser auch keine Brücke. |
| ChatGPT | nein | Entwicklermodus, dann Adresse. Bezahltes Konto nötig. |
| Gemini | nein | „Connected Apps" in der Web-App, Adresse. Verlangt ein öffentlich anerkanntes Zertifikat. |

**Der entscheidende Umweg heisst `mcp-remote`.** Zuerst stand hier, drei
von vier Clients könnten unseren Schlüssel nicht bedienen — das stimmt
für ihre *Connector-Dialoge*, aber die lokalen Clients können mehr:

```json
{
  "mcpServers": {
    "ownapp": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "<adresse>",
               "--header", "Authorization:${AUTH_HEADER}"],
      "env": { "AUTH_HEADER": "Bearer <schlüssel>" }
    }
  }
}
```

`mcp-remote` ist eine Brücke: nach aussen ein lokaler Server, den Claude
starten darf, nach innen ein Aufruf unserer Adresse **mit Header**. Damit
bleibt der Entwurf aus §2.2/§2.3 wie er ist, und Claude Desktop geht
trotzdem.

**Der Doppelpunkt ohne Leerzeichen ist kein Schönheitsfehler.** Claude
Desktop unter Windows reicht Argumente mit Leerzeichen falsch an `npx`
weiter und zerlegt den Header dabei; über die Umgebungsvariable kommt er
heil an. Genau dafür gibt es einen Test.

Was bleibt: **die reinen Web-Clients** (claude.ai, ChatGPT, Gemini) haben
keinen Weg, weil dort niemand einen lokalen Prozess starten kann. Wer den
Zugang dort einträgt, bekommt ein 404 — richtig so, aber es sieht aus wie
ein Fehler dieser App, und die Seite sagt es deshalb ausdrücklich.

Falls die je dazukommen sollen, gibt es zwei Wege, und beide kosten:

1. **OAuth nachrüsten.** Dann geht claude.ai. Es ist aber ein
   Anmeldeserver mit Registrierung, Zustimmungsseite und Token-Ablauf —
   deutlich mehr als dieser ganze Bauplan bis hierher.
2. **Den Schlüssel in die Adresse legen** (`/mcp/<slug>/<schlüssel>`).
   Dann geht alles, und §2.2 fällt: die URL wäre wieder das Passwort,
   mit allem, was dort steht — Server-Logs, Proxy-Logs,
   Konfigurationsdateien, Screenshots. Falls doch, dann als
   ausdrückliche zweite Tür mit eigenem Schalter und deutlichem Hinweis,
   nicht als stiller Ersatz.

---

## 16. Offene Entscheidungen

1. **Wird `user_ai_settings` mitgelöscht?** Sie ist seit Migration 010
   tot (§3.1). Mein Vorschlag: eine eigene, kleine Migration danach — ein
   Aufräumen gehört nicht in dieselbe Zeile wie ein Umbau.
2. **Wandert der Hell-/Dunkelmodus doch ans Konto?** Der Plan lässt ihn
   am Gerät, wegen des Küchentablets. Wer ihn am Konto will, bekommt
   einen Wert in der Tabelle und einen Schalter „auf diesem Gerät
   abweichen" — das ist eine eigene Runde.
3. **Soll ein zweiter Nutzer sehen, dass jemand einen MCP hat?**
   §6.3 sagt ja, aber nur im Haushalt und nur, wer freigegeben hat. Ob
   auch ohne Haushalt etwas sichtbar sein soll, ist offen — mein
   Vorschlag: nein, es geht dann niemanden etwas an.

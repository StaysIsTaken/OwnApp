# SKILLS.md — OwnApp

Für Agenten, die an diesem Projekt arbeiten. Kein Ersatz für die
`README.md` (die erklärt, *was* die App kann) — hier steht, **wie man hier
arbeitet und was schiefgeht, wenn man es nicht weiß.**

Alles auf Deutsch: Kommentare, Commit-Nachrichten, Testnamen, Oberfläche.

Das Gegenstück im Backend ist `OwnAPI/SKILLS.md`. Wer an einer Funktion
arbeitet, die beide Seiten berührt, liest beide.

---

## 1. Ausrollen

**Der Nutzer testet in Produktion.** Es gibt keine Testumgebung für die
App, und es braucht keine.

Der Ablauf ist kurz, weil **Watchtower** die Arbeit macht:

```bash
gh pr merge <n> --merge          # 1. mergen
gh run watch <id> --exit-status  # 2. Bau auf main abwarten (~4 min)
                                 # 3. warten – Watchtower tauscht selbst
```

Watchtower prüft alle 60 Sekunden und ersetzt den Container, wenn
`ghcr.io/staysistaken/ownapp:latest` neu ist. Es dauert typischerweise
ein bis zwei Minuten nach dem Bau.

**`docker restart webapp` bringt nichts.** Es startet den *alten*
Container neu und zieht kein neues Bild. Genau das ist mir einmal
passiert, und die Revision blieb unverändert — sie sah nur so aus, als
wäre etwas geschehen.

So prüfst du, ob der neue Stand wirklich läuft:

```bash
git rev-parse origin/main
ssh ownserver 'docker inspect webapp \
  --format "{{index .Config.Labels \"org.opencontainers.image.revision\"}}"'
```

Stimmen die beiden überein, ist es draußen. Zum Warten eine Schleife
statt blindem `sleep`:

```bash
ssh ownserver 'for i in $(seq 1 25); do
  r=$(docker inspect webapp --format "{{index .Config.Labels \"org.opencontainers.image.revision\"}}" 2>/dev/null)
  [ "$r" = "<sha>" ] && { echo "AKTUELL"; exit 0; }
  sleep 15
done; echo "NOCH ALT: $r"'
```

### Sag dem Nutzer, dass er hart neu laden muss

Flutter-Web hält die alte Fassung über einen Service Worker fest. **Ohne
Cmd/Strg + Shift + R sieht er deine Änderung nicht** — und meldet dann
einen Fehler, den es nicht gibt. Das ist in dieser Sitzung zweimal
passiert; einmal habe ich lange gesucht, bis mir auffiel, dass der Server
längst richtig auslieferte.

---

## 2. Der Server

`ownserver` in `~/.ssh/config`, erreichbar **nur über Tailscale**
(100.99.21.10). Ist Tailscale aus, läuft jeder `ssh` in einen Timeout:

```bash
/Applications/Tailscale.app/Contents/MacOS/Tailscale status
```

Der Pfad ist Absicht — das blanke `tailscale` wird hier blockiert. Steht
der Rechner nicht als `active` da, **frag den Nutzer, ob er Tailscale
einschalten kann.** Du kannst es nicht selbst. Bis dahin: entwickeln,
testen, PRs öffnen — nur nicht ausrollen.

Die Web-App läuft als **Portainer-Stack** (`/data/compose/50/`). Dieser
Pfad liegt *im Portainer-Container* und ist vom Host aus nicht lesbar —
`docker compose -f` schlägt fehl. Du brauchst ihn auch nicht: Watchtower
erledigt den Tausch.

---

## 3. Aufs Gerät bringen

```bash
./deploy/aufs-handy.sh              # iPhone am Kabel
./deploy/aufs-tablet.sh --anbieten  # Android ohne Kabel
```

Hängen mehrere Geräte dran, fragt das Skript. `--geraet "Malin"` nimmt
Name, Modell oder Kennung und überspringt die Frage — das brauchst du,
denn ohne Terminal wird nicht gefragt. `--liste` zeigt, was da ist.

**Das Profil gilt je Gerät, und darüber stolpert man.** `flutter build
ios` baut für ein *generisches* Gerät: es setzt `-destination
generic/platform=iOS` und fragt deshalb nie nach einem Profil für genau
dieses Telefon. Bei einem Gerät, das noch nicht im Profil steht,
scheitert dann erst das Installieren — mit `0xe8008012`, und die Meldung
zeigt auf die App statt auf die Ursache. Genau so ist hier ein iPhone 14
Plus hängengeblieben, obwohl Bauen und Signieren sauber durchliefen.

Deshalb baut das Skript über **`flutter run --release --no-resident -d
<udid>`**. Nur der Weg über `run` reicht die Kennung an Xcode durch
(`-destination id=…`, dazu `-allowProvisioningUpdates` und
`-allowProvisioningDeviceRegistration`) und lässt das Profil erneuern;
`--no-resident` beendet den Aufruf nach dem Start, statt anzuhängen. Ein
Lauf macht damit alles: bauen, signieren, registrieren, installieren,
starten.

Was am Gerät bleibt und kein Skript abnehmen kann: **Entwicklermodus**
(Einstellungen → Datenschutz & Sicherheit) und beim ersten Start das
Vertrauen zum Zertifikat (Einstellungen → Allgemein → VPN &
Geräteverwaltung). Beide Fälle fängt das Skript ab und sagt den Weg —
`devicectl` nennt sonst nur einen Fehlercode.

Das Entwicklerkonto ist ein **kostenloses**, Apple gibt dafür Profile mit
**sieben Tagen** Laufzeit. Danach startet die App nicht mehr, ohne dass
sich am Code etwas geändert hätte; das Skript nennt das Datum am Ende.
Nachsehen lässt es sich auch von Hand — aber **nicht** über „das neueste
Profil", das gehört bei mehreren Geräten womöglich zu einem anderen
Telefon:

```bash
for P in ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/*.mobileprovision; do
  security cms -D -i "$P" | grep -A1 -E 'ExpirationDate|ProvisionedDevices'
done
```

Ein Signieren **ohne angeschlossenes Gerät ist unmöglich** — die
Gerätekennung steht im Profil. Ein Server-Job dafür kann es nicht geben.

---

## 4. Tests

```bash
flutter analyze && flutter test
```

Beides muss sauber sein; die CI prüft `analyze` und ist streng.

### Was sich testen lässt und was nicht

**Testbar:** alles, was rechnet. Der Kachel-Baukasten
(`lib/tabs/dashboard/custom/`), Layoutrechnungen
(`lib/tabs/tablet/kachel_layout.dart`), Datenklassen, und **jedes Widget,
das seine Daten als Parameter bekommt** — davon gibt es inzwischen rund
dreißig zeichnende Tests.

**Nicht testbar:** Seiten, die beim Aufbau vom Server laden. Küchenseite,
Einkaufslisten, Preisseite, der Termin-Dialog. Sie zeigen im Test nur den
Ladekreis und lassen einen Timer offen, an dem der Test platzt. **Dafür
fehlt eine Attrappe** — sie zu bauen ist der offene Punkt Nummer eins.

Deshalb der Kunstgriff, der sich bewährt hat: **die Rechnung aus der
Seite herausziehen.** `hoeheGrosseKachel`, `inReihen`, `spaltenBedarf`
sind eigene Funktionen genau deswegen — die Seite ist nicht prüfbar, die
Rechnung dahinter schon.

### Zu jedem neuen Test die Gegenprobe

Code kaputt machen, Test laufen lassen, nachsehen ob er rot wird,
wiederherstellen:

```bash
cp -r lib /tmp/lib-heil
# kaputt machen, testen, dann:
rm -rf lib && cp -r /tmp/lib-heil lib
```

Bleibt der Test grün, prüft er nicht, was du glaubst. Das ist hier
mehrfach vorgekommen — einmal lief eine Testschleife über eine leere
Liste, einmal prüfte ein Test nur einen Konstruktor. Beide sahen
vernünftig aus und waren wertlos.

**Zeichnende Tests finden, was Logiktests nicht finden.** Der erste Lauf
überhaupt fand zwei echte Überlauffehler (`RenderFlex overflowed`), die
in Release still abgeschnitten wurden.

---

## 5. Der Kachel-Baukasten

`lib/tabs/dashboard/custom/` — eine Kachel ist **Quelle × Darstellung ×
Parameter × Filter.**

Jede Quelle erklärt ihre Datenform (`scalar`, `list`, `series`,
`distribution`, `text`, `schedule`, `board`, `checklist`, `ohne`), jede
Darstellung, welche Formen sie annimmt. **Es gibt keine gepflegte Liste
erlaubter Paarungen — sie ergibt sich.** Eine Torte nimmt nur
Verteilungen, eine Linie nur Verläufe.

Eine neue Quelle ist ein Eintrag in `TileCatalog.sources`; Oberfläche,
Editor und Speicherung ziehen automatisch nach.

Was eine Darstellung noch über sich sagt:

* `fuelltFlaeche` — ist ein Raster: nimmt die ganze Kachel und zeichnet
  sich auch ohne Daten. Eine leere Woche ist immer noch eine Woche.
* `minBreite` / `minHoehe` — unter welcher Größe sie unlesbar wird. Die
  Küchenseite gibt ihr lieber mehr Spalten, als sie darunter zu drücken;
  was dann nicht mehr in die Reihe passt, rutscht in die nächste.
* `TileKontext` — der Rückkanal. Fast alle Kacheln zeigen nur;
  Einkaufsliste und Board schreiben zurück.

---

## 6. Regeln, die du nicht umwerfen solltest

**Übersichtsseiten laden jede Datenquelle einzeln.** Ein fehlendes Recht
lässt eine Kachel weg, statt die Seite abzureißen. Vorher hingen elf
Dienste in einem `Future.wait` mit einem `catch` außen herum, und ein
403 in einem Bereich riss alles mit.

**Menüs auszublenden ist Höflichkeit, keine Absicherung.** Geprüft wird
im Backend, immer.

**Die Küchenansicht ist eine eigene kleine App.** Sie hängt an der Wand
und zeigt; nichts führt von dort in die große App. Was bleibt — Termin
anlegen, abhaken, Karten schieben — ist groß genug für einen Daumen mit
mehligen Fingern.

**Kein leerer String, wo eine Kennung hingehört.** Er sieht aus wie eine,
der Fremdschlüssel lehnt ihn ab, der Server stürzt ab, und im Browser
kommt es als CORS-Fehler an. Feld weglassen statt `''` schicken.

---

## 7. Beim Arbeiten

**Ausführen statt überlegen.** Erst nachsehen, was da ist.

**Gestapelte PRs sind eine Falle.** Wird der unterste gemergt, mergen die
darüber in einen Branch, der nicht mehr nach `main` führt. Von `main`
abzweigen — oder nach jedem Merge nachsehen, ob die Änderung wirklich
dort steht.

**Sag, was ungeprüft blieb.** Ob ein Layout auf dem Tablet gut aussieht,
ob ein Ton hörbar ist, ob eine Geste sich richtig anfühlt — das kann hier
niemand prüfen. Es gehört in den PR-Text.

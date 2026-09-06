#!/usr/bin/env bash
# Die App neu signieren und aufs angeschlossene iPhone bringen.
#
#   ./deploy/aufs-handy.sh            # bauen und installieren
#   ./deploy/aufs-handy.sh --ziehen   # vorher den neuesten Stand holen
#   ./deploy/aufs-handy.sh --starten  # nach dem Installieren gleich oeffnen
#
# WARUM WOECHENTLICH: das Entwicklerkonto ist ein kostenloses. Apple gibt
# dafuer Bereitstellungsprofile mit sieben Tagen Laufzeit -- danach startet
# die App nicht mehr, ohne dass sich am Programm etwas geaendert haette.
# Ein bezahltes Konto (99 EUR/Jahr) macht daraus ein Jahr; solange es das
# nicht gibt, ist dieses Skript die Woechentlichkeit.
#
# Das laesst sich NICHT ohne Handy erledigen: zum Signieren braucht Xcode
# das Geraet, weil die Geraetekennung im Profil steht. Deshalb kein
# Server-Job, sondern ein Kommando fuer den Moment, in dem das Kabel steckt.
set -euo pipefail

cd "$(dirname "$0")/.."

ZIEHEN=0
STARTEN=0
for arg in "$@"; do
  case "$arg" in
    --ziehen) ZIEHEN=1 ;;
    --starten) STARTEN=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Unbekannte Angabe: $arg" >&2; exit 1 ;;
  esac
done

fehler() { echo "✗ $*" >&2; exit 1; }
schritt() { echo ""; echo "→ $*"; }

# ── Vorbedingungen ──────────────────────────────────────────────────────
[ "$(uname)" = "Darwin" ] || fehler "Das geht nur auf einem Mac."
command -v xcrun >/dev/null || fehler "Xcode-Werkzeuge fehlen (xcode-select --install)."
command -v flutter >/dev/null || fehler "flutter ist nicht im Pfad."

if ! security find-identity -v -p codesigning 2>/dev/null | grep -q 'Apple Development'; then
  fehler "Keine Signatur im Schluesselbund. Einmal Xcode oeffnen, ios/Runner.xcworkspace,
  unter Signing & Capabilities die Apple-ID auswaehlen -- danach geht es hier weiter."
fi

# ── Geraet suchen ───────────────────────────────────────────────────────
schritt "Nach dem iPhone suchen"
GERAET=$(xcrun devicectl list devices --json-output /dev/stdout --quiet 2>/dev/null | python3 -c '
import json, sys
try:
    daten = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for g in daten.get("result", {}).get("devices", []):
    eigenschaften = g.get("deviceProperties", {})
    verbindung = g.get("connectionProperties", {})
    # Nur was gerade wirklich erreichbar ist -- "unavailable" heisst
    # bekannt, aber nicht angeschlossen.
    if verbindung.get("tunnelState") == "unavailable":
        continue
    art = g.get("hardwareProperties", {}).get("deviceType", "")
    if art and art != "iPhone":
        continue
    print(g.get("identifier", "") + "\t" + eigenschaften.get("name", "?"))
    break
' || true)

if [ -z "$GERAET" ]; then
  fehler "Kein iPhone gefunden.
  Kabel pruefen, Geraet entsperren und \"Diesem Computer vertrauen\" bestaetigen.
  Was der Mac sieht: xcrun devicectl list devices"
fi

KENNUNG="${GERAET%%$'\t'*}"
NAME="${GERAET##*$'\t'}"
echo "  $NAME"

# ── Stand holen ─────────────────────────────────────────────────────────
if [ "$ZIEHEN" = "1" ]; then
  schritt "Neuesten Stand holen"
  git pull --ff-only
fi

schritt "Abhaengigkeiten"
flutter pub get >/dev/null

# ── Bauen ───────────────────────────────────────────────────────────────
# Hier wird auch signiert: das Projekt steht auf automatischer Signierung,
# Xcode zieht sich beim Bauen ein frisches Profil fuer die naechsten sieben
# Tage. Genau deshalb reicht Bauen -- ein eigener Signierschritt entfaellt.
schritt "Bauen und signieren (dauert ein paar Minuten)"
flutter build ios --release

APP="build/ios/iphoneos/Runner.app"
[ -d "$APP" ] || fehler "Gebaut, aber $APP fehlt -- da ist beim Bauen etwas schiefgegangen."

# ── Installieren ────────────────────────────────────────────────────────
schritt "Auf $NAME installieren"
xcrun devicectl device install app --device "$KENNUNG" "$APP"

if [ "$STARTEN" = "1" ]; then
  schritt "Starten"
  BUNDLE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")
  xcrun devicectl device process launch --device "$KENNUNG" "$BUNDLE" || \
    echo "  (Starten hat nicht geklappt -- von Hand oeffnen)"
fi

# ── Wie lange haelt es? ─────────────────────────────────────────────────
PROFIL=$(ls -t ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/*.mobileprovision 2>/dev/null | head -1 || true)
if [ -n "$PROFIL" ]; then
  ABLAUF=$(security cms -D -i "$PROFIL" 2>/dev/null \
    | grep -A1 '<key>ExpirationDate</key>' | tail -1 \
    | sed 's/.*<date>\(.*\)<\/date>.*/\1/')
  echo ""
  echo "✓ Fertig. Das Profil laeuft am ${ABLAUF%T*} ab."
  echo "  Danach dasselbe nochmal -- oder ein bezahltes Konto, dann haelt es ein Jahr."
else
  echo ""
  echo "✓ Fertig."
fi

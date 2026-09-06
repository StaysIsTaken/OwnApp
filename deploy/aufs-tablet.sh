#!/usr/bin/env bash
# Die App aufs Android-Tablet bringen.
#
#   ./deploy/aufs-tablet.sh                  # bauen und per Kabel/adb installieren
#   ./deploy/aufs-tablet.sh --funk 192.168.1.42:5555
#                                            # vorher drahtlos verbinden
#   ./deploy/aufs-tablet.sh --anbieten       # bauen und zum Herunterladen anbieten
#   ./deploy/aufs-tablet.sh --ziehen         # vorher den neuesten Stand holen
#
# Drei Wege, weil ein Tablet an der Kuechenwand selten am Kabel haengt:
#
#   Kabel     schnell und ohne Nachfragen, wenn man drankommt
#   Funk      einmal koppeln, danach reicht die Adresse (Android 11+)
#   Anbieten  gar keine Entwicklereinstellung noetig -- das Tablet holt
#             sich die Datei im Browser
set -euo pipefail

cd "$(dirname "$0")/.."

ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
ADB="$ANDROID_HOME/platform-tools/adb"

ZIEHEN=0
ANBIETEN=0
FUNKZIEL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ziehen) ZIEHEN=1 ;;
    --anbieten) ANBIETEN=1 ;;
    --funk) shift; FUNKZIEL="${1:-}"; [ -n "$FUNKZIEL" ] || { echo "--funk braucht eine Adresse, z.B. 192.168.1.42:5555" >&2; exit 1; } ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "Unbekannte Angabe: $1" >&2; exit 1 ;;
  esac
  shift
done

fehler() { echo "✗ $*" >&2; exit 1; }
schritt() { echo ""; echo "→ $*"; }

command -v flutter >/dev/null || fehler "flutter ist nicht im Pfad."

if [ "$ZIEHEN" = "1" ]; then
  schritt "Neuesten Stand holen"
  git pull --ff-only
fi

# ── Bauen ───────────────────────────────────────────────────────────────
schritt "Bauen (dauert ein bis zwei Minuten)"
flutter pub get >/dev/null
flutter build apk --release

APK="build/app/outputs/flutter-apk/app-release.apk"
[ -f "$APK" ] || fehler "Gebaut, aber $APK fehlt."
GROESSE=$(du -h "$APK" | cut -f1)
echo "  $APK ($GROESSE)"

# ── Weg 3: zum Herunterladen anbieten ───────────────────────────────────
if [ "$ANBIETEN" = "1" ]; then
  ADRESSE=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "")
  [ -n "$ADRESSE" ] || fehler "Keine Netzwerkadresse gefunden -- haengt der Mac im WLAN?"

  ORDNER=$(mktemp -d)
  cp "$APK" "$ORDNER/ownapp.apk"

  echo ""
  echo "  Auf dem Tablet im Browser oeffnen:"
  echo ""
  echo "      http://$ADRESSE:8000/ownapp.apk"
  echo ""
  echo "  Danach in der Benachrichtigung auf die Datei tippen und die"
  echo "  Installation aus unbekannter Quelle einmal erlauben."
  echo "  Zum Beenden: Strg-C"
  echo ""
  cd "$ORDNER"
  # Nur an dieses Netz gebunden, nicht an alle Schnittstellen -- die Datei
  # soll im WLAN erreichbar sein und sonst nirgends.
  exec python3 -m http.server 8000 --bind "$ADRESSE"
fi

# ── Weg 2: drahtlos verbinden ───────────────────────────────────────────
[ -x "$ADB" ] || fehler "adb fehlt unter $ADB.
  Entweder ANDROID_HOME setzen oder --anbieten nehmen, das braucht kein adb."

if [ -n "$FUNKZIEL" ]; then
  schritt "Drahtlos verbinden mit $FUNKZIEL"
  "$ADB" connect "$FUNKZIEL" || fehler "Verbindung fehlgeschlagen.
  Auf dem Tablet: Entwickleroptionen → Drahtloses Debugging einschalten.
  Beim ersten Mal koppeln: adb pair <adresse:port> mit dem angezeigten Code."
fi

# ── Weg 1: Geraet suchen und installieren ───────────────────────────────
schritt "Nach dem Tablet suchen"
GERAET=$("$ADB" devices | awk 'NR>1 && $2=="device" {print $1; exit}')

if [ -z "$GERAET" ]; then
  UNBERECHTIGT=$("$ADB" devices | awk 'NR>1 && $2=="unauthorized" {print $1; exit}')
  if [ -n "$UNBERECHTIGT" ]; then
    fehler "Das Tablet fragt noch. Auf dem Bildschirm \"USB-Debugging zulassen\" bestaetigen."
  fi
  fehler "Kein Tablet gefunden.
  Per Kabel:   Entwickleroptionen → USB-Debugging einschalten, dann anschliessen.
  Drahtlos:    $0 --funk <adresse:port>
  Ohne alles:  $0 --anbieten"
fi

MODELL=$("$ADB" -s "$GERAET" shell getprop ro.product.model 2>/dev/null | tr -d '\r' || echo "?")
echo "  $MODELL ($GERAET)"

schritt "Installieren"
# -r ersetzt eine vorhandene Fassung und behaelt die Daten.
if ! "$ADB" -s "$GERAET" install -r "$APK"; then
  echo ""
  fehler "Installation fehlgeschlagen.
  Steht dort etwas von SIGNATURE oder INSTALL_FAILED_UPDATE_INCOMPATIBLE,
  wurde die vorhandene App mit einem anderen Schluessel signiert. Dann
  einmal deinstallieren und neu installieren:
      $ADB -s $GERAET uninstall de.jpanft.homeapp"
fi

echo ""
echo "✓ Fertig. Die App liegt auf $MODELL."

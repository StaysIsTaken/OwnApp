#!/usr/bin/env bash
# Die App aufs Android-Tablet bringen.
#
# Laeuft auf macOS, Linux und Windows (Git Bash). Android-Entwicklung geht auf
# allen dreien, das Kuechentablet haengt aber nicht immer am selben Rechner --
# deshalb sucht das Skript seine Werkzeuge, statt sie an einer Stelle zu
# erwarten.
#
# Drei Wege, weil ein Tablet an der Kuechenwand selten am Kabel haengt:
#
#   Kabel     schnell und ohne Nachfragen, wenn man drankommt
#   Funk      einmal koppeln, danach reicht die Adresse (Android 11+)
#   Anbieten  gar keine Entwicklereinstellung noetig -- das Tablet holt
#             sich die Datei im Browser
set -euo pipefail

cd "$(dirname "$0")/.."

hilfe() {
  cat <<'ENDE'
Die App aufs Android-Tablet bringen.

  ./deploy/aufs-tablet.sh                  bauen und per Kabel/adb installieren
  ./deploy/aufs-tablet.sh --funk 192.168.1.42:5555
                                           vorher drahtlos verbinden
  ./deploy/aufs-tablet.sh --anbieten       bauen und zum Herunterladen anbieten
  ./deploy/aufs-tablet.sh --ziehen         vorher den neuesten Stand holen
ENDE
}

fehler() { echo "✗ $*" >&2; exit 1; }
schritt() { echo ""; echo "→ $*"; }

# ── Welches System? ─────────────────────────────────────────────────────
# Die Unterschiede sind klein, aber jeder einzelne bringt das Skript sonst
# zum Stehen: die .exe-Endung, der Ort des SDK, das Ermitteln der eigenen
# Adresse.
case "$(uname -s)" in
  Darwin*)              SYSTEM=mac ;;
  Linux*)               SYSTEM=linux ;;
  MINGW*|MSYS*|CYGWIN*) SYSTEM=windows ;;
  *)                    SYSTEM=unbekannt ;;
esac

ZIEHEN=0
ANBIETEN=0
FUNKZIEL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ziehen) ZIEHEN=1 ;;
    --anbieten) ANBIETEN=1 ;;
    --funk) shift; FUNKZIEL="${1:-}"; [ -n "$FUNKZIEL" ] || fehler "--funk braucht eine Adresse, z.B. 192.168.1.42:5555" ;;
    -h|--help) hilfe; exit 0 ;;
    *) echo "Unbekannte Angabe: $1" >&2; hilfe >&2; exit 1 ;;
  esac
  shift
done

# ── Werkzeuge suchen ────────────────────────────────────────────────────

# Windows-Pfade aus der Umgebung (C:\Users\...) sind fuer bash unbrauchbar,
# solange die Trennzeichen falsch herum stehen.
entwirren() { printf '%s' "${1//\\//}"; }

adb_finden() {
  # Im Pfad zuerst: wer adb dort hat, hat sich dabei etwas gedacht.
  if command -v adb >/dev/null 2>&1; then command -v adb; return; fi

  local orte="" ort datei lokal
  [ -n "${ANDROID_HOME:-}" ]     && orte="$orte $(entwirren "$ANDROID_HOME")"
  [ -n "${ANDROID_SDK_ROOT:-}" ] && orte="$orte $(entwirren "$ANDROID_SDK_ROOT")"
  case "$SYSTEM" in
    mac)   orte="$orte /opt/homebrew/share/android-commandlinetools $HOME/Library/Android/sdk" ;;
    linux) orte="$orte $HOME/Android/Sdk /usr/lib/android-sdk" ;;
    windows)
      lokal=$(entwirren "${LOCALAPPDATA:-}")
      [ -n "$lokal" ] && orte="$orte $lokal/Android/Sdk"
      orte="$orte /c/src/android-sdk"
      ;;
  esac

  for ort in $orte; do
    for datei in "$ort/platform-tools/adb" "$ort/platform-tools/adb.exe"; do
      [ -x "$datei" ] && { printf '%s' "$datei"; return; }
    done
  done
}

# http.server braucht Python 3. Unter Windows gibt es oft nur `python`, und
# `python3` ist dort haeufig der Platzhalter aus dem Microsoft Store, der
# beim Aufruf nur auf sich selbst verweist -- deshalb wird jeder Kandidat
# einmal wirklich ausgefuehrt.
python_finden() {
  local p
  for p in python3 python py; do
    if command -v "$p" >/dev/null 2>&1 \
       && "$p" -c 'import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1; then
      printf '%s' "$p"
      return
    fi
  done
}

adresse_finden() {
  local a=""
  case "$SYSTEM" in
    mac)
      a=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)
      ;;
    linux)
      a=$(hostname -I 2>/dev/null | awk '{print $1}')
      [ -n "$a" ] || a=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')
      ;;
    windows)
      # Die Ausgabe ist uebersetzt ("IPv4 Address" / "IPv4-Adresse"), das
      # Kuerzel IPv4 steht aber in jeder Sprache drin.
      a=$(ipconfig 2>/dev/null | tr -d '\r' | awk -F: '/IPv4/ {gsub(/ /,"",$2); print $2; exit}')
      ;;
  esac
  printf '%s' "$a"
}

command -v flutter >/dev/null 2>&1 || fehler "flutter ist nicht im Pfad.
  macOS/Linux:  export PATH=\"\$PATH:/pfad/zu/flutter/bin\"
  Windows:      C:\\pfad\\zu\\flutter\\bin in die PATH-Variable aufnehmen"

if [ "$ZIEHEN" = "1" ]; then
  schritt "Neuesten Stand holen"
  git pull --ff-only
fi

# ── Bauen ───────────────────────────────────────────────────────────────
#
# Je Architektur ein eigenes APK statt eines gemeinsamen. Der Grund ist die
# ONNX-Laufzeit hinter der Weckworterkennung: libonnxruntime.so wiegt je
# Architektur 14 bis 24 MB, und ein gemeinsames Paket schleppt alle drei mit
# -- rund 158 MB, von denen ein Geraet zwei Drittel nie anfasst. Einzeln sind
# es etwa 65 MB.
schritt "Bauen (dauert ein bis zwei Minuten)"
flutter pub get >/dev/null
flutter build apk --release --split-per-abi

# Welche Architektur das Geraet braucht, verraet es selbst. Ohne adb (also bei
# --anbieten) ist arm64 die richtige Annahme: alles, was in den letzten Jahren
# gebaut wurde, laeuft darauf.
apk_fuer() {
  local abi="${1:-arm64-v8a}"
  local kandidat="build/app/outputs/flutter-apk/app-$abi-release.apk"
  [ -f "$kandidat" ] && { printf '%s' "$kandidat"; return; }
  # Falls jemand die Aufteilung wieder herausnimmt, greift das gemeinsame.
  local gemeinsam="build/app/outputs/flutter-apk/app-release.apk"
  [ -f "$gemeinsam" ] && printf '%s' "$gemeinsam"
}

# ── Weg 3: zum Herunterladen anbieten ───────────────────────────────────
if [ "$ANBIETEN" = "1" ]; then
  PYTHON=$(python_finden)
  [ -n "$PYTHON" ] || fehler "Python 3 nicht gefunden -- ohne das gibt es keinen kleinen Webserver.
  Alternative: das Tablet per Kabel anschliessen und ohne --anbieten aufrufen."

  ADRESSE=$(adresse_finden)
  [ -n "$ADRESSE" ] || fehler "Keine Netzwerkadresse gefunden -- haengt der Rechner im WLAN?"

  APK=$(apk_fuer arm64-v8a)
  [ -n "$APK" ] || fehler "Gebaut, aber kein APK gefunden."
  echo "  $APK ($(du -h "$APK" | cut -f1)) -- arm64, ohne adb nicht genauer bestimmbar"

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
  exec "$PYTHON" -m http.server 8000 --bind "$ADRESSE"
fi

# ── Weg 2: drahtlos verbinden ───────────────────────────────────────────
ADB=$(adb_finden)
[ -n "$ADB" ] || fehler "adb nicht gefunden.
  Entweder ANDROID_HOME auf das SDK zeigen lassen, platform-tools in den
  Pfad aufnehmen, oder --anbieten nehmen -- das braucht kein adb."

if [ -n "$FUNKZIEL" ]; then
  schritt "Drahtlos verbinden mit $FUNKZIEL"
  "$ADB" connect "$FUNKZIEL" || fehler "Verbindung fehlgeschlagen.
  Auf dem Tablet: Entwickleroptionen → Drahtloses Debugging einschalten.
  Beim ersten Mal koppeln: adb pair <adresse:port> mit dem angezeigten Code."
fi

# ── Weg 1: Geraet suchen und installieren ───────────────────────────────
schritt "Nach dem Tablet suchen"
# tr entfernt das \r, das adb unter Windows anhaengt -- ohne das steht es
# mitten im Geraetenamen und jeder Vergleich geht schief.
GERAET=$("$ADB" devices | tr -d '\r' | awk 'NR>1 && $2=="device" {print $1; exit}')

if [ -z "$GERAET" ]; then
  UNBERECHTIGT=$("$ADB" devices | tr -d '\r' | awk 'NR>1 && $2=="unauthorized" {print $1; exit}')
  if [ -n "$UNBERECHTIGT" ]; then
    fehler "Das Tablet fragt noch. Auf dem Bildschirm \"USB-Debugging zulassen\" bestaetigen."
  fi
  fehler "Kein Tablet gefunden.
  Per Kabel:   Entwickleroptionen → USB-Debugging einschalten, dann anschliessen.
  Drahtlos:    $0 --funk <adresse:port>
  Ohne alles:  $0 --anbieten"
fi

MODELL=$("$ADB" -s "$GERAET" shell getprop ro.product.model 2>/dev/null | tr -d '\r' || echo "?")
ABI=$("$ADB" -s "$GERAET" shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r' || echo "arm64-v8a")
echo "  $MODELL ($GERAET, $ABI)"

APK=$(apk_fuer "$ABI")
[ -n "$APK" ] || fehler "Fuer $ABI wurde kein APK gebaut.
  Vorhanden: $(ls build/app/outputs/flutter-apk/*.apk 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"
echo "  $APK ($(du -h "$APK" | cut -f1))"

schritt "Installieren"
# -r ersetzt eine vorhandene Fassung und behaelt die Daten.
if ! "$ADB" -s "$GERAET" install -r "$APK"; then
  # Den Paketnamen aus dem Gradle-Stand lesen statt ihn hier zu wiederholen:
  # eine falsche Angabe im Hinweis kostet mehr Zeit als gar keine.
  PAKET=$(awk -F'"' '/applicationId/ {print $2; exit}' android/app/build.gradle.kts 2>/dev/null)
  echo ""
  fehler "Installation fehlgeschlagen.
  Steht dort etwas von SIGNATURE oder INSTALL_FAILED_UPDATE_INCOMPATIBLE,
  wurde die vorhandene App mit einem anderen Schluessel signiert. Dann
  einmal deinstallieren und neu installieren (das loescht die App-Daten
  auf dem Geraet, der Server bleibt unberuehrt):
      $ADB -s $GERAET uninstall ${PAKET:-<paketname>}"
fi

echo ""
echo "✓ Fertig. Die App liegt auf $MODELL."

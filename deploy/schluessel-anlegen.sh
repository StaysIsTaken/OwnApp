#!/usr/bin/env bash
# Den Signaturschluessel fuer die Freigabe-APK anlegen. Einmal, dann nie wieder.
#
# WARUM ES DEN BRAUCHT: bisher wurde die Freigabe-APK mit dem *Debug*-
# Schluessel signiert. Den legt das Android-SDK auf jedem Rechner selbst an,
# und er ist auf jedem ein anderer. Kommt das naechste Update von einem
# anderen Mac, lehnt Android es ab:
#
#     INSTALL_FAILED_UPDATE_INCOMPATIBLE: signatures do not match
#
# Dann hilft nur Deinstallieren, und das loescht die App-Daten auf dem
# Geraet. Mit einem eigenen Schluessel passiert das nie wieder -- solange
# es derselbe bleibt.
#
# DESHALB IST DIESE DATEI UNERSETZLICH. Geht sie verloren, laesst sich die
# App auf keinem Geraet mehr aktualisieren; jedes muss einmal
# deinstallieren. Es gibt kein Zuruecksetzen und niemanden, der hilft --
# auch Google nicht, denn hier ist kein Play Store im Spiel.
#
#   ./deploy/schluessel-anlegen.sh
#
# Das Passwort wird abgefragt und steht nirgends im Klartext auf der
# Kommandozeile -- sonst stuende es in der Prozessliste und in der
# Shell-Historie.
set -euo pipefail

cd "$(dirname "$0")/.."

fehler() { echo "✗ $*" >&2; exit 1; }

# Ausserhalb des Arbeitsverzeichnisses, und das ist Absicht: was nicht im
# Repository liegt, kann auch nicht versehentlich hineincommittet werden.
# `.gitignore` faengt es zusaetzlich ab, aber ein Netz allein traegt nicht.
SCHLUESSELORT="${OWNAPP_SCHLUESSEL:-$HOME/.ownapp/ownapp-release.jks}"
EIGENSCHAFTEN="android/key.properties"
ALIAS="ownapp"

# ── keytool finden ──────────────────────────────────────────────────────
# Es kommt mit dem JDK, und das steckt bei Android-Entwicklern meist in
# Android Studio statt im Pfad.
KEYTOOL="$(command -v keytool || true)"
if [ -z "$KEYTOOL" ]; then
  for ORT in \
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" \
    "$HOME/Library/Java/JavaVirtualMachines"/*/Contents/Home/bin/keytool \
    "/usr/lib/jvm"/*/bin/keytool
  do
    [ -x "$ORT" ] && { KEYTOOL="$ORT"; break; }
  done
fi
[ -n "$KEYTOOL" ] || fehler "keytool nicht gefunden. Es gehoert zum JDK --
  unter macOS liegt es in Android Studio:
  /Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"

# ── Nichts ueberschreiben ───────────────────────────────────────────────
# Ein vorhandener Schluessel wird NIE ersetzt. Waere er weg, liessen sich
# alle Geraete nicht mehr aktualisieren -- und gemerkt haette man es erst
# beim naechsten Installieren.
if [ -f "$SCHLUESSELORT" ]; then
  echo "→ Es gibt schon einen Schluessel: $SCHLUESSELORT"
  echo "  Der bleibt. Zum Weiterverwenden auf einem anderen Rechner diese"
  echo "  Datei dorthin kopieren und das Skript dort erneut ausfuehren --"
  echo "  es schreibt dann nur $EIGENSCHAFTEN."
  echo ""
else
  mkdir -p "$(dirname "$SCHLUESSELORT")"
  chmod 700 "$(dirname "$SCHLUESSELORT")"

  echo "→ Schluessel anlegen: $SCHLUESSELORT"
  echo ""
  echo "  Gleich wird ein Passwort abgefragt (zweimal). MINDESTENS SECHS"
  echo "  ZEICHEN -- keytool lehnt kuerzere ab und fragt dann einfach noch"
  echo "  einmal, ohne dass man den Grund gleich sieht."
  echo ""
  echo "  Merk es dir gut: ohne das Passwort ist der Schluessel wertlos,"
  echo "  und ohne den Schluessel laesst sich die App auf keinem Geraet"
  echo "  mehr aktualisieren."
  echo ""
  echo "  Die Angaben zu Name und Ort danach sind fuer eine App ausserhalb"
  echo "  des Play Store ohne Bedeutung; Enter genuegt ueberall."
  echo ""

  # 10000 Tage ~ 27 Jahre. Laeuft der Schluessel ab, laesst sich nicht mehr
  # signieren -- und der Ersatz waere wieder ein anderer Schluessel mit
  # allem, was daran haengt.
  "$KEYTOOL" -genkeypair \
    -v \
    -keystore "$SCHLUESSELORT" \
    -storetype JKS \
    -keyalg RSA \
    -keysize 4096 \
    -validity 10000 \
    -alias "$ALIAS"

  chmod 600 "$SCHLUESSELORT"
fi

# ── key.properties schreiben ────────────────────────────────────────────
# Gradle liest sie; sie steht in .gitignore. Das Passwort hier steht im
# Klartext -- das ist bei Android so vorgesehen und der Grund, warum die
# Datei das Repository nie sehen darf.
if [ -f "$EIGENSCHAFTEN" ]; then
  echo ""
  echo "→ $EIGENSCHAFTEN gibt es schon, bleibt unveraendert."
else
  echo ""
  echo "→ $EIGENSCHAFTEN anlegen"
  echo "  Dasselbe Passwort noch einmal, diesmal damit Gradle es kennt."
  printf "  Passwort: "
  read -rs PASSWORT
  echo ""
  [ -n "$PASSWORT" ] || fehler "Leeres Passwort -- abgebrochen."

  umask 077
  cat > "$EIGENSCHAFTEN" <<ENDE
# Von deploy/schluessel-anlegen.sh erzeugt. Steht in .gitignore und
# gehoert dort hin: hier steht ein Passwort im Klartext.
storeFile=$SCHLUESSELORT
storePassword=$PASSWORT
keyAlias=$ALIAS
keyPassword=$PASSWORT
ENDE
  chmod 600 "$EIGENSCHAFTEN"
  unset PASSWORT
fi

# ── Probe ───────────────────────────────────────────────────────────────
echo ""
echo "→ Probe: passt das Passwort zum Schluessel?"
if "$KEYTOOL" -list -keystore "$SCHLUESSELORT" \
     -storepass "$(grep '^storePassword=' "$EIGENSCHAFTEN" | cut -d= -f2-)" \
     >/dev/null 2>&1; then
  echo "  ja"
else
  fehler "Das Passwort in $EIGENSCHAFTEN passt nicht zum Schluessel.
  Datei loeschen und das Skript noch einmal ausfuehren."
fi

cat <<'ENDE'

✓ Fertig. Ab jetzt signiert `flutter build apk --release` mit diesem
  Schluessel, und `deploy/aufs-tablet.sh` nimmt ihn automatisch mit.

  ZWEI DINGE NOCH, UND DAS ERSTE IST WICHTIG:

  1. SICHERE DEN SCHLUESSEL UND DAS PASSWORT. Nicht im Repository --
     in einen Passwortmanager oder auf einen Datentraeger, der nicht
     dieser Rechner ist. Geht beides verloren, muss jedes Geraet die App
     einmal deinstallieren, und dabei gehen seine App-Daten mit.

  2. DER ERSTE EINBAU KOSTET EINMAL EINE DEINSTALLATION. Was heute auf
     den Geraeten liegt, ist mit dem Debug-Schluessel signiert und passt
     nicht zum neuen. Also einmal:

         adb uninstall com.example.productivity

     Danach nie wieder -- genau dafuer ist der Schluessel da.
ENDE

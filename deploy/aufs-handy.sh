#!/usr/bin/env bash
# Die App neu signieren und aufs angeschlossene iPhone bringen.
#
#   ./deploy/aufs-handy.sh                       # fragt, wenn mehrere dranhaengen
#   ./deploy/aufs-handy.sh --geraet "Malin"      # ohne Rueckfrage dieses
#   ./deploy/aufs-handy.sh --liste               # nur zeigen, was da ist
#   ./deploy/aufs-handy.sh --ziehen              # vorher den neuesten Stand holen
#
# WOHIN: haengen mehrere Geraete dran, fragt das Skript und laesst dich
# waehlen; am Kabel angeschlossene stehen oben und sind die Vorgabe. Ein
# Telefon, das nur im WLAN sichtbar ist, steht meist bloss herum. Ohne
# Terminal (Cron, CI) wird nicht gefragt, dann gewinnt das Kabel -- und
# bei mehreren gleichrangigen bricht es ab, statt zu raten.
#
# WARUM EIN LAUF FUER ALLES: das Bereitstellungsprofil gilt je Geraet.
# "flutter build ios" baut fuer ein GENERISCHES Geraet und fragt deshalb
# nie nach einem Profil fuer genau dieses Telefon -- ein neues Handy
# scheitert dann beim Installieren mit 0xe8008012. "flutter run" reicht
# die Kennung an Xcode durch (-destination id=..., zusammen mit
# -allowProvisioningDeviceRegistration) und laesst das Profil erneuern.
# Deshalb baut, signiert, installiert und startet hier ein einziger
# Aufruf; --no-resident sorgt dafuer, dass er sich danach beendet.
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
NURLISTE=0
WUNSCH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ziehen) ZIEHEN=1 ;;
    --liste) NURLISTE=1 ;;
    --geraet) shift; [ $# -gt 0 ] || { echo "--geraet braucht Namen oder Kennung" >&2; exit 1; }; WUNSCH="$1" ;;
    --geraet=*) WUNSCH="${1#*=}" ;;
    # "flutter run" startet die App ohnehin. Die alte Angabe bleibt
    # zulaessig, damit niemand ueber sein Muskelgedaechtnis stolpert.
    --starten) ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unbekannte Angabe: $1" >&2; exit 1 ;;
  esac
  shift
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

# ── Geraete einlesen ────────────────────────────────────────────────────
# Eine Zeile je Geraet: Kennung, Name, Modell, kabel|funk. Die Kennung ist
# die UDID aus hardwareProperties -- genau die, die "flutter run -d"
# erwartet. Die daneben stehende "identifier" ist eine andere und passt
# nur zu devicectl.
schritt "Nach Geraeten suchen"
GERAETE=$(xcrun devicectl list devices --json-output /dev/stdout --quiet 2>/dev/null | python3 -c '
import json, sys

try:
    daten = json.load(sys.stdin)
except Exception:
    sys.exit(0)

zeilen = []
for g in daten.get("result", {}).get("devices", []):
    technik = g.get("hardwareProperties", {})
    verbindung = g.get("connectionProperties", {})
    # "unavailable" heisst bekannt, aber gerade nicht erreichbar.
    if verbindung.get("tunnelState") == "unavailable":
        continue
    art = technik.get("deviceType", "")
    if art not in ("iPhone", "iPad"):
        continue
    udid = technik.get("udid", "")
    if not udid:
        continue
    zeilen.append("\t".join([
        udid,
        g.get("deviceProperties", {}).get("name", "?"),
        technik.get("productType", "?"),
        "kabel" if verbindung.get("transportType") == "wired" else "funk",
    ]))

# Kabel nach oben: das ist die Reihenfolge, in der gefragt wird, und die
# Vorgabe ist die erste Zeile.
zeilen.sort(key=lambda z: 0 if z.endswith("kabel") else 1)
print("\n".join(zeilen))
' || true)

KENNUNGEN=(); NAMEN=(); MODELLE=(); WEGE=()
while IFS=$'\t' read -r k n m w; do
  [ -n "${k:-}" ] || continue
  KENNUNGEN+=("$k"); NAMEN+=("$n"); MODELLE+=("$m"); WEGE+=("$w")
done <<< "$GERAETE"

ANZAHL=${#KENNUNGEN[@]}
if [ "$ANZAHL" -eq 0 ]; then
  fehler "Kein iPhone gefunden.
  Kabel pruefen, Geraet entsperren und \"Diesem Computer vertrauen\" bestaetigen.
  Was der Mac sieht: xcrun devicectl list devices"
fi

zeige_liste() {
  local i
  for i in $(seq 0 $((ANZAHL - 1))); do
    printf "  %d) %-24s %-12s %s\n" "$((i + 1))" "${NAMEN[$i]}" "${MODELLE[$i]}" \
      "$([ "${WEGE[$i]}" = "kabel" ] && echo "am Kabel" || echo "im WLAN")"
  done
}

if [ "$NURLISTE" = "1" ]; then
  zeige_liste
  exit 0
fi

# ── Auswaehlen ──────────────────────────────────────────────────────────
GEWAEHLT=-1

if [ -n "$WUNSCH" ]; then
  # Name als Teilstueck, Kennung vollstaendig. Passt es auf mehrere, ist
  # die Angabe zu unscharf -- lieber nachfragen lassen als raten.
  klein() { echo "$1" | tr '[:upper:]' '[:lower:]'; }
  W=$(klein "$WUNSCH")
  TREFFER=()
  for i in $(seq 0 $((ANZAHL - 1))); do
    N=$(klein "${NAMEN[$i]}"); K=$(klein "${KENNUNGEN[$i]}"); M=$(klein "${MODELLE[$i]}")
    case "$N" in *"$W"*) TREFFER+=("$i"); continue ;; esac
    case "$M" in *"$W"*) TREFFER+=("$i"); continue ;; esac
    [ "$K" = "$W" ] && TREFFER+=("$i")
  done
  if [ ${#TREFFER[@]} -eq 1 ]; then
    GEWAEHLT=${TREFFER[0]}
  elif [ ${#TREFFER[@]} -eq 0 ]; then
    zeige_liste >&2
    fehler "Nichts passt auf \"$WUNSCH\". Oben steht, was da ist."
  else
    zeige_liste >&2
    fehler "\"$WUNSCH\" passt auf mehrere. Genauer, oder die Kennung nehmen."
  fi
elif [ "$ANZAHL" -eq 1 ]; then
  GEWAEHLT=0
elif { exec 3</dev/tty; } 2>/dev/null; then
  # Erst oeffnen, dann fragen. Ein blosses [ -r /dev/tty ] sagt noch
  # nicht, dass da wirklich jemand sitzt -- die Datei kann lesbar sein
  # und das Lesen trotzdem scheitern. Dann waere die stille Vorgabe eine
  # Entscheidung, die niemand getroffen hat.
  echo ""
  echo "  Mehrere Geraete. Wohin soll die App?"
  zeige_liste
  echo ""
  printf "  Nummer [1]: "
  if ! read -r ANTWORT <&3; then
    exec 3<&-
    echo ""
    fehler "Abgebrochen."
  fi
  exec 3<&-
  ANTWORT="${ANTWORT:-1}"
  case "$ANTWORT" in
    ''|*[!0-9]*) fehler "\"$ANTWORT\" ist keine Nummer aus der Liste." ;;
  esac
  [ "$ANTWORT" -ge 1 ] && [ "$ANTWORT" -le "$ANZAHL" ] \
    || fehler "$ANTWORT steht nicht in der Liste."
  GEWAEHLT=$((ANTWORT - 1))
else
  # Ohne Terminal kann niemand antworten. Dann entscheidet das Kabel --
  # und nur, wenn es eindeutig ist.
  AMKABEL=()
  for i in $(seq 0 $((ANZAHL - 1))); do
    [ "${WEGE[$i]}" = "kabel" ] && AMKABEL+=("$i")
  done
  if [ ${#AMKABEL[@]} -eq 1 ]; then
    GEWAEHLT=${AMKABEL[0]}
  else
    zeige_liste >&2
    fehler "Mehrere Geraete und keine Moeglichkeit zu fragen. --geraet \"<Name>\" angeben."
  fi
fi

KENNUNG="${KENNUNGEN[$GEWAEHLT]}"
NAME="${NAMEN[$GEWAEHLT]}"
echo "  $NAME (${MODELLE[$GEWAEHLT]}, $([ "${WEGE[$GEWAEHLT]}" = "kabel" ] && echo "am Kabel" || echo "im WLAN"))"

# ── Stand holen ─────────────────────────────────────────────────────────
if [ "$ZIEHEN" = "1" ]; then
  schritt "Neuesten Stand holen"
  git pull --ff-only
fi

schritt "Abhaengigkeiten"
flutter pub get >/dev/null

# ── Bauen, signieren, installieren, starten ─────────────────────────────
APP="build/ios/iphoneos/Runner.app"
PROTOKOLL=$(mktemp -t aufs-handy)
trap 'rm -f "$PROTOKOLL"' EXIT

deute_fehler() {
  case "$1" in
    *"Developer Mode is disabled"*|*"developer mode"*)
      fehler "Auf $NAME ist der Entwicklermodus aus.
  Am Telefon: Einstellungen → Datenschutz & Sicherheit → Entwicklermodus
  einschalten, Neustart bestaetigen, entsperren. Danach noch einmal."
      ;;
    *0xe8008012*|*"provisioning profile cannot be installed"*)
      fehler "Das Profil passt nicht zu $NAME.
  Das sollte hier eigentlich von selbst geschehen. Wenn nicht, hat das
  kostenlose Konto meist sein Geraetekontingent voll -- dann in Xcode
  unter Settings → Accounts → Manage Certificates aufraeumen."
      ;;
    *"device is locked"*|*"Unlock"*|*"passcode"*)
      fehler "$NAME ist gesperrt. Entsperren und noch einmal."
      ;;
    *"requires a development team"*|*"No profiles for"*|*"Signing for"*)
      fehler "Xcode kann nicht signieren.
  Einmal ios/Runner.xcworkspace oeffnen, unter Signing & Capabilities die
  Apple-ID waehlen -- danach geht es hier wieder allein."
      ;;
    *)
      fehler "Fehlgeschlagen -- der Grund steht darueber."
      ;;
  esac
}

schritt "Fuer $NAME bauen und draufspielen (dauert ein paar Minuten)"
BEGONNEN=$(date +%s)
VERTRAUEN_FEHLT=0

if ! flutter run --release --no-resident -d "$KENNUNG" 2>&1 | tee "$PROTOKOLL"; then
  echo ""
  # Bau kaputt, oder nur das Draufspielen? Das steht nicht in der Meldung
  # -- "Could not run ... Try launching Xcode" sagt flutter zu beidem.
  # Am Ergebnis ist es aber zu sehen: liegt ein frisch gebautes Bundle da,
  # war der Bau in Ordnung.
  if [ -d "$APP" ] && [ "$(stat -f %m "$APP")" -ge "$BEGONNEN" ]; then
    # Ab hier uebernimmt devicectl. Nicht aus Sturheit: es nennt den
    # Grund, waehrend flutter an dieser Stelle auf Xcode verweist.
    schritt "Gebaut ist es -- selbst draufspielen"
    if ! AUSGABE=$(xcrun devicectl device install app --device "$KENNUNG" "$APP" 2>&1); then
      echo "$AUSGABE" >&2
      deute_fehler "$AUSGABE"
    fi
    echo "  installiert"

    BUNDLE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")
    if ! AUSGABE=$(xcrun devicectl device process launch --device "$KENNUNG" "$BUNDLE" 2>&1); then
      case "$AUSGABE" in
        *"not been explicitly trusted"*|*"Untrusted"*|*"trust this developer"*)
          # Kein Fehlschlag: die App liegt drauf. Bei einem Telefon, das
          # zum ersten Mal ein selbstsigniertes Programm bekommt, ist
          # dieser Handgriff immer faellig -- Apple laesst ihn nicht
          # aus der Ferne erledigen.
          VERTRAUEN_FEHLT=1
          ;;
        *)
          echo "$AUSGABE" >&2
          echo "  (Starten hat nicht geklappt -- von Hand oeffnen)"
          ;;
      esac
    else
      echo "  gestartet"
    fi
  else
    deute_fehler "$(cat "$PROTOKOLL")"
  fi
fi

# ── Wie lange haelt es? ─────────────────────────────────────────────────
# Nicht einfach das neueste Profil nehmen: bei mehreren Geraeten gehoert
# das juengste womoeglich zu einem anderen Telefon.
ABLAUF=$(KENNUNG="$KENNUNG" python3 -c '
import glob, os, plistlib, subprocess, sys

gesucht = os.environ["KENNUNG"]
spaet = None
for pfad in glob.glob(os.path.expanduser(
        "~/Library/Developer/Xcode/UserData/Provisioning Profiles/*.mobileprovision")):
    try:
        roh = subprocess.run(["security", "cms", "-D", "-i", pfad],
                             capture_output=True, check=True).stdout
        profil = plistlib.loads(roh)
    except Exception:
        continue
    if gesucht not in (profil.get("ProvisionedDevices") or []):
        continue
    endet = profil.get("ExpirationDate")
    if endet and (spaet is None or endet > spaet):
        spaet = endet

print(spaet.date().isoformat() if spaet else "")
' 2>/dev/null || true)

echo ""
if [ "$VERTRAUEN_FEHLT" = "1" ]; then
  echo "✓ Auf $NAME installiert -- starten darf sie noch nicht."
  echo ""
  echo "  Am Telefon einmal freigeben:"
  echo "  Einstellungen → Allgemein → VPN & Geraeteverwaltung → Entwickler-App"
  echo "  → \"Apple Development: ...\" → Vertrauen."
  echo ""
  echo "  Das ist bei einem Geraet, das zum ersten Mal ein selbstsigniertes"
  echo "  Programm bekommt, immer faellig und aus der Ferne nicht zu machen."
  echo "  Danach oeffnet sich die App vom Startbildschirm; dieses Kommando"
  echo "  muss dafuer nicht noch einmal laufen."
else
  echo "✓ Fertig."
fi

if [ -n "$ABLAUF" ]; then
  echo ""
  echo "  Das Profil laeuft am $ABLAUF ab. Danach dasselbe nochmal --"
  echo "  oder ein bezahltes Konto, dann haelt es ein Jahr."
fi

#!/usr/bin/env bash
# Alles ausrollen: Server zuerst, App danach, Geraete zuletzt.
#
#   ./deploy/rollout.sh                 alles, mit Rueckfrage vor Produktion
#   ./deploy/rollout.sh --nur-api       nur den Server
#   ./deploy/rollout.sh --nur-app       nur die App (Web + angeschlossene Geraete)
#   ./deploy/rollout.sh --ohne-geraete  Web ja, Kabel nein
#   ./deploy/rollout.sh --ja            keine Rueckfragen
#   ./deploy/rollout.sh --probe         nur zeigen, was geschehen wuerde
#
# WARUM DIE REIHENFOLGE FESTSTEHT: die App spricht mit dem Server. Geht sie
# zuerst live, ruft sie Endpunkte auf, die es noch nicht gibt -- und der
# Nutzer sieht Fehler fuer etwas, das gerade erst besser wurde. Server
# zuerst ist die einzige Richtung, die in beiden Faellen funktioniert:
# ein neuer Server mit alter App laeuft, umgekehrt nicht.
#
# WAS DAS SKRIPT NICHT TUT: mergen. Was in `main` landet, entscheidet ein
# Mensch am Pull Request. Das Skript rollt aus, was schon dort steht --
# alles andere waere ein Knopf, der auf einen Klick die halbe Wohnung
# umstellt.
set -euo pipefail

APP="$(cd "$(dirname "$0")/.." && pwd)"
API="${OWNAPI_PFAD:-$(cd "$APP/../OwnAPI" 2>/dev/null && pwd || true)}"
SERVER="${OWNSERVER:-ownserver}"

NUR=""
GERAETE=1
FRAGEN=1
PROBE=0

for arg in "$@"; do
  case "$arg" in
    --nur-api) NUR="api" ;;
    --nur-app) NUR="app" ;;
    --ohne-geraete) GERAETE=0 ;;
    --ja) FRAGEN=0 ;;
    --probe) PROBE=1; FRAGEN=0 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "Unbekannte Angabe: $arg" >&2; exit 1 ;;
  esac
done

fehler() { echo "" >&2; echo "✗ $*" >&2; exit 1; }
schritt() { echo ""; echo "── $*"; }
tu() {
  if [ "$PROBE" = "1" ]; then echo "   [Probe] $*"; else "$@"; fi
}

frage() {
  [ "$FRAGEN" = "1" ] || return 0
  echo ""
  read -r -p "$1 [j/N] " antwort
  case "$antwort" in j|J|ja|Ja) return 0 ;; *) fehler "Abgebrochen." ;; esac
}

# ── Vorbedingungen ──────────────────────────────────────────────────────
# Alle auf einmal, bevor irgendetwas passiert. Auf halbem Weg zu merken,
# dass `gh` fehlt, ist die unangenehmste Art, das zu erfahren.
schritt "Vorbedingungen"
command -v gh >/dev/null || fehler "gh fehlt (brew install gh)."
gh auth status >/dev/null 2>&1 || fehler "gh ist nicht angemeldet (gh auth login)."

if [ "$NUR" != "app" ]; then
  [ -n "$API" ] && [ -d "$API/.git" ] \
    || fehler "OwnAPI nicht gefunden. Erwartet neben OwnApp, oder OWNAPI_PFAD setzen."
  ssh -o ConnectTimeout=10 -o BatchMode=yes "$SERVER" true 2>/dev/null \
    || fehler "Kein Zugang zu '$SERVER'. Tailscale an? (ssh $SERVER)"
fi
echo "   App:    $APP"
[ "$NUR" != "app" ] && echo "   API:    $API"
[ "$NUR" != "app" ] && echo "   Server: $SERVER"

# ── Was ueberhaupt ansteht ──────────────────────────────────────────────
# Bevor gefragt wird, wofuer: die Antwort haengt daran, wie viel drinsteckt.
zeige_anstehendes() {
  ( cd "$1" && git fetch origin main -q 2>/dev/null || true
    echo "   $2: $(git log origin/main --oneline -1)" )
}

schritt "Stand"
[ "$NUR" != "app" ] && zeige_anstehendes "$API" "API"
[ "$NUR" != "api" ] && zeige_anstehendes "$APP" "App"

# ── Server ──────────────────────────────────────────────────────────────
if [ "$NUR" != "app" ]; then
  schritt "Server: auf den Bauvorgang warten"
  (
    cd "$API"
    # Das :test-Bild entsteht beim Merge in main. Ohne es gibt es nichts
    # freizugeben -- und `promote` wuerde ein altes Bild auf :prod heben.
    if [ "$PROBE" = "1" ]; then
      echo "   [Probe] auf 'Build & Push' warten"
    else
      local_status=""
      for _ in $(seq 1 60); do
        local_status=$(gh run list --branch main --workflow 'Build & Push' \
          --limit 1 --json status --jq '.[0].status' 2>/dev/null || echo "")
        [ "$local_status" = "completed" ] && break
        printf "."
        sleep 20
      done
      echo ""
      ergebnis=$(gh run list --branch main --workflow 'Build & Push' \
        --limit 1 --json conclusion --jq '.[0].conclusion')
      [ "$ergebnis" = "success" ] \
        || fehler "Der Bauvorgang ist '$ergebnis'. Ohne gruenes Bild kein Ausrollen."
      echo "   Bild :test steht."
    fi
  )

  frage "Das auf PRODUKTION freigeben?"

  schritt "Server: :test auf :prod heben"
  ( cd "$API" && tu gh workflow run promote.yml )
  if [ "$PROBE" != "1" ]; then
    sleep 5
    ( cd "$API" && gh run watch "$(gh run list --workflow promote.yml --limit 1 \
        --json databaseId --jq '.[0].databaseId')" --exit-status >/dev/null ) \
      || fehler "Das Freigeben ist fehlgeschlagen."
    echo "   :prod zeigt auf den neuen Stand."
  fi

  schritt "Server: neu starten (mit Datenbankabzug und Migration)"
  # update.sh zieht ZUERST einen Abzug. Die Migration laeuft beim Start des
  # Containers und laesst sich nicht zuruecknehmen -- ein Bild kann man
  # zurueckhaengen, eine gelaufene Migration nicht.
  tu ssh "$SERVER" "cd ~/ownapi && ./deploy/update.sh prod"

  if [ "$PROBE" != "1" ]; then
    schritt "Server: antwortet er?"
    if ssh "$SERVER" 'curl -sf -o /dev/null -w "%{http_code}" http://localhost:8000/docs' \
       2>/dev/null | grep -q '^2'; then
      echo "   ✓ Der Server antwortet."
    else
      echo "   ! Der Server antwortet nicht (noch nicht?). Nachsehen:"
      echo "     ssh $SERVER 'docker logs --tail 50 ownapi-prod-api-1'"
    fi
  fi
fi

# ── App: Web ────────────────────────────────────────────────────────────
if [ "$NUR" != "api" ]; then
  schritt "App: Web"
  # Watchtower tauscht ownapp:latest von selbst, sobald das Bild da ist.
  # Hier wird deshalb nichts angestossen, nur gewartet und nachgesehen.
  (
    cd "$APP"
    if [ "$PROBE" = "1" ]; then
      echo "   [Probe] auf den App-Bauvorgang warten, dann Watchtower"
    else
      for _ in $(seq 1 60); do
        s=$(gh run list --branch main --limit 1 --json status --jq '.[0].status' 2>/dev/null || echo "")
        [ "$s" = "completed" ] && break
        printf "."
        sleep 20
      done
      echo ""
      e=$(gh run list --branch main --limit 1 --json conclusion --jq '.[0].conclusion')
      if [ "$e" = "success" ]; then
        echo "   Bild steht. Watchtower tauscht es von selbst -- das dauert bis zu"
        echo "   einer Runde. Sofort geht auch:"
        echo "     ssh $SERVER 'docker pull ghcr.io/staysistaken/ownapp:latest && docker restart webapp'"
      else
        echo "   ! Der App-Bauvorgang ist '$e'. Das Web bleibt auf dem alten Stand."
      fi
    fi
  )
fi

# ── App: angeschlossene Geraete ─────────────────────────────────────────
# Das ist der Teil, der sich nicht vom Server erledigen laesst: iOS braucht
# zum Signieren das Geraet am Kabel, weil die Geraetekennung im Profil
# steht. Deshalb hier und nicht in einem Job.
if [ "$NUR" != "api" ] && [ "$GERAETE" = "1" ]; then
  schritt "Geraete am Kabel"
  gefunden=0

  if command -v adb >/dev/null 2>&1; then
    if adb devices 2>/dev/null | awk 'NR>1 && $2=="device"' | grep -q .; then
      echo "   Android gefunden."
      gefunden=1
      tu bash "$APP/deploy/aufs-tablet.sh"
    fi
  fi

  if [ "$(uname)" = "Darwin" ] && command -v xcrun >/dev/null 2>&1; then
    if xcrun devicectl list devices 2>/dev/null | grep -q 'connected'; then
      echo "   iPhone gefunden."
      gefunden=1
      tu bash "$APP/deploy/aufs-handy.sh"
    fi
  fi

  [ "$gefunden" = "0" ] && echo "   Nichts angeschlossen -- uebersprungen."
fi

echo ""
echo "✓ Fertig."

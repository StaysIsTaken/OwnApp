#!/usr/bin/env bash
# Erinnert woechentlich daran, die App neu aufs Handy zu bringen.
#
#   ./deploy/woechentliche-erinnerung.sh ein   # einrichten
#   ./deploy/woechentliche-erinnerung.sh aus   # wieder entfernen
#   ./deploy/woechentliche-erinnerung.sh test  # Meldung sofort zeigen
#
# WARUM NUR ERINNERN: das Signieren braucht das angeschlossene Geraet --
# die Geraetekennung steht im Profil. Ein Job, der es allein versucht,
# scheitert in sechs von sieben Faellen und macht die Meldung wertlos.
# Also sagt der Mac Bescheid, und du steckst das Kabel ein.
set -euo pipefail

PROJEKT="$(cd "$(dirname "$0")/.." && pwd)"
KENNUNG="de.jpanft.homeapp.erinnerung"
PLIST="$HOME/Library/LaunchAgents/$KENNUNG.plist"

# Sonntags um 18 Uhr: das Profil haelt sieben Tage, ein fester Wochentag
# laesst nie mehr als sieben dazwischen liegen.
WOCHENTAG=0
STUNDE=18

meldung() {
  osascript -e 'display notification "Das Signierprofil läuft diese Woche ab. iPhone anschließen und ./deploy/aufs-handy.sh ausführen." with title "OwnApp aufs Handy" sound name "Glass"' 2>/dev/null || true
}

case "${1:-}" in
  ein)
    mkdir -p "$HOME/Library/LaunchAgents"
    cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$KENNUNG</string>
  <key>ProgramArguments</key>
  <array>
    <string>$PROJEKT/deploy/woechentliche-erinnerung.sh</string>
    <string>test</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key><integer>$WOCHENTAG</integer>
    <key>Hour</key><integer>$STUNDE</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
</dict>
</plist>
PLISTEOF
    launchctl unload "$PLIST" 2>/dev/null || true
    launchctl load "$PLIST"
    echo "✓ Eingerichtet: sonntags um ${STUNDE}:00."
    echo "  Wieder weg mit: $0 aus"
    ;;
  aus)
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    echo "✓ Entfernt."
    ;;
  test)
    meldung
    ;;
  *)
    sed -n '2,12p' "$0"
    exit 1
    ;;
esac

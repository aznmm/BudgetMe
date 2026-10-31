#!/bin/bash
# Turns automatic renewal of BudgetMe on your iPhone on or off.
# When it's on, this Mac checks every evening at 8 PM (or when it next wakes up) and renews
# the app if it's been 5 days or more, so the free 7-day signing never runs out.
#
#   scripts/auto-renew.sh on
#   scripts/auto-renew.sh off
#   scripts/auto-renew.sh status
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
LABEL="com.budgetme.renew"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/BudgetMe-renew.log"
DOMAIN="gui/$(id -u)"

case "${1:-}" in
on)
    mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
    cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$REPO/scripts/renew-iphone.sh</string>
        <string>--auto</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>20</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>$LOG</string>
    <key>StandardErrorPath</key>
    <string>$LOG</string>
</dict>
</plist>
EOF
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    launchctl bootstrap "$DOMAIN" "$PLIST"
    echo "Automatic renewal is on. Every evening at 8 PM this Mac renews BudgetMe if it's been 5 days or more."
    echo "What happened each time is written to $LOG"
    ;;
off)
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    rm -f "$PLIST"
    echo "Automatic renewal is off."
    ;;
status)
    if launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then
        echo "Automatic renewal is on."
    else
        echo "Automatic renewal is off."
    fi
    if [[ -f "$LOG" ]]; then
        echo "Last entries:"
        tail -n 5 "$LOG"
    fi
    ;;
*)
    echo "Usage: scripts/auto-renew.sh on | off | status" >&2
    exit 1
    ;;
esac

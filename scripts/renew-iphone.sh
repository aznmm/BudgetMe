#!/bin/bash
# Renews BudgetMe on your iPhone before the free 7-day signing runs out.
# It builds the app and installs it over the copy on your phone, so your data stays.
#
#   scripts/renew-iphone.sh          renew now
#   scripts/renew-iphone.sh --auto   renew only if the last renewal was 5 or more days ago
#                                    (what the daily schedule from auto-renew.sh runs)
#
# Set BUDGETME_DEVICE to an iPhone's name or identifier if more than one is paired with this Mac.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$REPO/build/renew"
STAMP="$BUILD_DIR/last-renewed"
APP="$BUILD_DIR/Debug-iphoneos/BudgetMe.app"

# The schedule runs with a bare environment, so point at Xcode itself rather than the command line tools.
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M')] $1"
}

notify() {
    /usr/bin/osascript -e "display notification \"$1\" with title \"BudgetMe\"" >/dev/null 2>&1 || true
}

fail() {
    log "$1"
    notify "$1"
    exit 1
}

if [[ "${1:-}" == "--auto" && -f "$STAMP" ]]; then
    days=$(( ($(date +%s) - $(cat "$STAMP")) / 86400 ))
    if (( days < 5 )); then
        log "Renewed $days day(s) ago, nothing to do."
        exit 0
    fi
fi

mkdir -p "$BUILD_DIR"
DEVICES_JSON="$(mktemp)"
trap 'rm -f "$DEVICES_JSON"' EXIT

DEVICE="${BUDGETME_DEVICE:-}"
if [[ -z "$DEVICE" ]]; then
    xcrun devicectl list devices --json-output "$DEVICES_JSON" >/dev/null 2>&1 \
        || fail "Couldn't look for your iPhone. Is Xcode installed?"
    # The first paired iPhone, or any iPhone if pairing isn't reported.
    DEVICE="$(/usr/bin/python3 - "$DEVICES_JSON" <<'PY'
import json, sys

devices = json.load(open(sys.argv[1])).get("result", {}).get("devices", [])
iphones = [d for d in devices if d.get("hardwareProperties", {}).get("deviceType") == "iPhone"]
paired = [d for d in iphones if d.get("connectionProperties", {}).get("pairingState") == "paired"]
for device in paired or iphones:
    print(device.get("identifier", ""))
    break
PY
)"
fi
[[ -n "$DEVICE" ]] || fail "No iPhone found. Plug it in once and run BudgetMe on it from Xcode."

log "Building BudgetMe…"
xcodebuild \
    -project "$REPO/BudgetMe.xcodeproj" \
    -target BudgetMe \
    -configuration Debug \
    -sdk iphoneos \
    -allowProvisioningUpdates \
    -quiet \
    SYMROOT="$BUILD_DIR" \
    build \
    || fail "The build failed. Open BudgetMe in Xcode and press Cmd+R to see why."

log "Installing on your iPhone…"
xcrun devicectl device install app --device "$DEVICE" "$APP" \
    || fail "Couldn't reach your iPhone. Keep it unlocked on the same Wi-Fi as this Mac; it'll try again tomorrow."

date +%s > "$STAMP"
log "Renewed. Good for another 7 days."
notify "Renewed on your iPhone. Good for another 7 days."

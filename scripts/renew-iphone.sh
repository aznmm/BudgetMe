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

# Xcode keeps reusing a cached signing profile until the day it expires, so a day-5 build would only
# last two more days. Removing BudgetMe's cached profile makes Xcode issue a fresh 7-day one.
BUNDLE_ID="$(sed -n 's/.*PRODUCT_BUNDLE_IDENTIFIER = \(.*\);/\1/p' "$REPO/BudgetMe.xcodeproj/project.pbxproj" | head -1)"
for profile in "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"/*.mobileprovision; do
    [[ -f "$profile" && -n "$BUNDLE_ID" ]] || continue
    if security cms -D -i "$profile" 2>/dev/null \
        | plutil -extract Entitlements.application-identifier raw -o - - 2>/dev/null \
        | grep -q "\.$BUNDLE_ID\$"; then
        rm -f "$profile"
    fi
done

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
expires="$(security cms -D -i "$APP/embedded.mobileprovision" 2>/dev/null \
    | plutil -extract ExpirationDate raw -o - - 2>/dev/null)" || expires=""
if [[ -n "$expires" ]]; then
    expires="$(date -r "$(TZ=UTC date -j -f '%Y-%m-%dT%H:%M:%SZ' "$expires" +%s)" '+%A %-d %B at %-I:%M %p')"
    log "Renewed. Works until $expires."
    notify "Renewed on your iPhone. Works until $expires."
else
    log "Renewed. Good for another 7 days."
    notify "Renewed on your iPhone. Good for another 7 days."
fi

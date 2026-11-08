#!/bin/zsh
# Builds Pocket for the Simulator and takes the README screenshots in docs/screenshots/.
#
#   scripts/screenshots.sh [simulator udid]     # default: the first available iPhone 17 Pro
#
# Use a freshly erased Simulator (xcrun simctl erase <udid>): the first-launch
# shot needs Pocket to have no cache, and the Home Screen widgets go on the
# first page as it ships. To get "9:41" rather than "09:41" in the status bar,
# set the Simulator to a 12-hour clock first, then restart it:
#   xcrun simctl spawn <udid> defaults write -g AppleICUForce12HourTime -bool true
#
# Every app shot uses -PocketNoSplash. The converter shots use -PocketDemoRates,
# which stands in the bundled rates for a download at 09:41, so they always show
# $100 → ₦134,660.13. The offline ones use -PocketOffline.
set -euo pipefail

cd "$(dirname "$0")/.."
UDID="${1:-$(xcrun simctl list devices available | grep -E '^ +iPhone 17 Pro \(' | head -1 | grep -oE '[0-9A-F-]{36}')}"
DERIVED="${DERIVED:-build/DerivedData}"
DEST="id=$UDID"
OUT=docs/screenshots

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" >/dev/null
xcodebuild build -scheme Pocket -destination "$DEST" -derivedDataPath "$DERIVED" -quiet
APP="$DERIVED/Build/Products/Debug-iphonesimulator/Pocket.app"
BUNDLE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")
xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"

# A clean status bar: 9:41, full signal and Wi-Fi, a full battery.
xcrun simctl status_bar "$UDID" override --time 9:41 \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100

shot() { # appearance, file, launch arguments...
  local appearance=$1 file=$2; shift 2
  xcrun simctl ui "$UDID" appearance "$appearance"
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" -PocketNoSplash "$@" >/dev/null
  sleep 3
  xcrun simctl io "$UDID" screenshot "$OUT/$file" >/dev/null 2>&1
  echo "wrote $OUT/$file"
}

mkdir -p "$OUT"
# Fresh install, no network: the rates that ship in the app.
shot light airplane-first-launch.png -PocketOffline
# "Downloads" the demo rates, which also fills the cache for the shots after.
shot light converter-light.png -PocketDemoRates
shot dark converter-dark.png -PocketDemoRates
shot light currency-search.png -PocketDemoRates -PocketOpenPicker
# The cache from above, with the network gone.
shot dark offline-cached.png -PocketOffline
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl ui "$UDID" appearance light

# Home Screen: a UI test adds the small and medium widgets through
# SpringBoard's Add Widget sheet and leaves the first page showing.
TEST_RUNNER_POCKET_ADD_WIDGETS=1 xcodebuild test -scheme Pocket -destination "$DEST" -derivedDataPath "$DERIVED" \
  -only-testing:PocketUITests/HomeScreenWidgetSetup -quiet
sleep 3
xcrun simctl io "$UDID" screenshot "$OUT/widgets-home.png" >/dev/null 2>&1
echo "wrote $OUT/widgets-home.png"

# Lock Screen: drawn from the real widget view, see PocketTests/WidgetScreenshots.swift.
TEST_RUNNER_POCKET_WIDGET_SHOTS=1 xcodebuild test -scheme Pocket -destination "$DEST" -derivedDataPath "$DERIVED" \
  -only-testing:PocketTests/WidgetScreenshots -quiet
echo "wrote $OUT/widget-lock.png"

xcrun simctl status_bar "$UDID" clear

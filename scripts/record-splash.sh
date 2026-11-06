#!/bin/zsh
# Records the opening animation in the simulator so you can watch it on the Mac.
#
#   scripts/record-splash.sh            build, then record normal speed and 4x slow motion
#   scripts/record-splash.sh --no-build record the build that's already there
#
# Videos land in ~/Movies/Pocket splash/ and open in QuickTime.
set -euo pipefail

cd "$(dirname "$0")/.."
SIM_NAME="iPhone 17 Pro"
DEST="platform=iOS Simulator,name=$SIM_NAME,OS=26.1"
OUT="$HOME/Movies/Pocket splash"
mkdir -p "$OUT"

SIM=$(xcrun simctl list devices available | grep -E "^ +$SIM_NAME \(" | head -1 | grep -oE '[0-9A-F-]{36}')
xcrun simctl boot "$SIM" 2>/dev/null || true

if [[ "${1:-}" != "--no-build" ]]; then
  xcodebuild build -scheme Pocket -destination "$DEST" -quiet
fi
APP=$(xcodebuild -scheme Pocket -destination "$DEST" -showBuildSettings 2>/dev/null | awk -F' = ' '/ CODESIGNING_FOLDER_PATH /{print $2; exit}')
BID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist")
xcrun simctl install "$SIM" "$APP"

STAMP=$(date +%H%M%S)
record() { # name, seconds, launch args...
  local name=$1 secs=$2; shift 2
  local raw="$OUT/.raw.mov" file="$OUT/$STAMP-$name.mp4"
  xcrun simctl terminate "$SIM" "$BID" 2>/dev/null || true
  xcrun simctl io "$SIM" recordVideo --codec h264 --force "$raw" >/dev/null 2>&1 &
  local rec=$!
  sleep 1.5
  xcrun simctl launch "$SIM" "$BID" "$@" >/dev/null
  sleep "$secs"
  kill -INT $rec; wait $rec 2>/dev/null || true
  # Keep it small and playable anywhere.
  ffmpeg -loglevel error -y -i "$raw" -vf "scale=-2:1280" -c:v libx264 -pix_fmt yuv420p "$file"
  rm -f "$raw"
  echo "$file"
}

NORMAL=$(record normal 5)
SLOW=$(record slow-4x 11 -PocketSplashSlow)
open -a "QuickTime Player" "$NORMAL" "$SLOW"

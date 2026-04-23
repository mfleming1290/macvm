#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="macvm Agent.app"
APP_DIR="$AGENT_DIR/build/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"

cd "$AGENT_DIR"
swift build

BIN_DIR="$(swift build --show-bin-path)"
EXECUTABLE="$BIN_DIR/MacAgent"
WEBRTC_FRAMEWORK="$BIN_DIR/LiveKitWebRTC.framework"

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Missing built MacAgent executable at $EXECUTABLE" >&2
  exit 1
fi

if [[ ! -d "$WEBRTC_FRAMEWORK" ]]; then
  echo "Missing LiveKitWebRTC.framework at $WEBRTC_FRAMEWORK" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$FRAMEWORKS_DIR"

cp "$EXECUTABLE" "$MACOS_DIR/MacAgent"
cp "$AGENT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp -R "$WEBRTC_FRAMEWORK" "$FRAMEWORKS_DIR/"

if ! otool -l "$MACOS_DIR/MacAgent" | grep -q "@executable_path/../Frameworks"; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/MacAgent"
fi

codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "$APP_DIR"

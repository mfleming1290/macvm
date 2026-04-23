#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="macvm Agent.app"
APP_DIR="$AGENT_DIR/build/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"

usage() {
  cat <<'EOF'
Usage: build-dev-app.sh [--signing-identity "Apple Development: Name (TEAMID)"]

Environment:
  MACVM_CODESIGN_IDENTITY   Preferred codesigning identity for the development app.
                            Use "adhoc" or "-" to force ad-hoc signing.

If no identity is provided, the script will use the first available Apple Development
certificate from the local keychain. If none is available, it falls back to ad-hoc
signing and prints that mode explicitly.
EOF
}

requested_identity="${MACVM_CODESIGN_IDENTITY:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --signing-identity)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --signing-identity" >&2
        exit 1
      fi
      requested_identity="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

available_identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"

resolve_signing_identity() {
  local requested="$1"

  if [[ -n "$requested" ]]; then
    if [[ "$requested" == "-" || "$requested" == "adhoc" ]]; then
      echo "-|forced ad-hoc fallback"
      return
    fi

    if grep -Fq "\"$requested\"" <<<"$available_identities"; then
      echo "$requested|configured signing identity"
      return
    fi

    echo "Requested signing identity not found in keychain: $requested" >&2
    exit 1
  fi

  local discovered_identity
  discovered_identity="$(
    awk -F\" '/"Apple Development: / { print $2; exit }' <<<"$available_identities"
  )"

  if [[ -n "$discovered_identity" ]]; then
    echo "$discovered_identity|auto-detected Apple Development identity"
    return
  fi

  echo "-|ad-hoc fallback (permissions may need to be re-granted after rebuilds)"
}

resolved_signing="$(resolve_signing_identity "$requested_identity")"
SIGNING_IDENTITY="${resolved_signing%%|*}"
SIGNING_MODE="${resolved_signing#*|}"

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

mkdir -p "$MACOS_DIR" "$FRAMEWORKS_DIR"

echo "macvm: app bundle path: $APP_DIR"
echo "macvm: signing mode: $SIGNING_MODE"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  echo "macvm: signing identity: ad-hoc"
else
  echo "macvm: signing identity: $SIGNING_IDENTITY"
fi

rm -f "$MACOS_DIR/MacAgent"
rm -f "$CONTENTS_DIR/Info.plist"
rm -rf "$FRAMEWORKS_DIR/LiveKitWebRTC.framework"

install -m 755 "$EXECUTABLE" "$MACOS_DIR/MacAgent"
cp "$AGENT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp -R "$WEBRTC_FRAMEWORK" "$FRAMEWORKS_DIR/"

if ! otool -l "$MACOS_DIR/MacAgent" | grep -q "@executable_path/../Frameworks"; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/MacAgent"
fi

codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none "$FRAMEWORKS_DIR/LiveKitWebRTC.framework" >/dev/null
codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none "$APP_DIR" >/dev/null
codesign --verify --deep --strict "$APP_DIR" >/dev/null

echo "macvm: signing verification:"
codesign -dv --verbose=4 "$APP_DIR" 2>&1 | grep -E "Identifier=|Authority=|TeamIdentifier=|Signature=" || true

echo "$APP_DIR"

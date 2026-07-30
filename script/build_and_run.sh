#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="PDFNavigator"
CONFIGURATION="Debug"
APP_ARGUMENTS=()

if [[ "$MODE" == "--release" || "$MODE" == "release" ]]; then
  MODE="run"
  CONFIGURATION="Release"
elif [[ "$MODE" == "--appkit-shell" || "$MODE" == "appkit-shell" ]]; then
  MODE="run"
  APP_ARGUMENTS=(
    "--appkit-window-shell"
    "-ApplePersistenceIgnoreState"
    "YES"
  )
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/xcode"
APP_BUNDLE="$BUILD_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

if [[ -d /Applications/Xcode-beta.app ]]; then
  export DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

xcodebuild \
  -project "$ROOT_DIR/PDFNavigator.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  build

open_app() {
  if [[ "${#APP_ARGUMENTS[@]}" -eq 0 ]]; then
    /usr/bin/open -n "$APP_BUNDLE"
  else
    /usr/bin/open -n "$APP_BUNDLE" --args "${APP_ARGUMENTS[@]}"
  fi
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream \
      --info \
      --style compact \
      --predicate "process == \"$APP_NAME\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo \
      "usage: $0 [run|--release|--appkit-shell|--debug|--logs|--verify]" \
      >&2
    exit 2
    ;;
esac

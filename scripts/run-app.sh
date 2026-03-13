#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="$ROOT_DIR/build"
PROJECT_FILE="$ROOT_DIR/PasteDock.xcodeproj/project.pbxproj"
BUILD_APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/PasteDock.app"
INSTALL_APP_PATH="/Applications/PasteDock.app"

cd "$ROOT_DIR"
if command -v xcodegen >/dev/null 2>&1; then
  if [[ ! -f "$PROJECT_FILE" || "$ROOT_DIR/project.yml" -nt "$PROJECT_FILE" ]]; then
    xcodegen generate
  fi
fi

xcodebuild -project PasteDock.xcodeproj -scheme PasteDock -configuration Debug -derivedDataPath "$DERIVED_DATA_PATH" build
pkill -x PasteDock >/dev/null 2>&1 || true
ditto "$BUILD_APP_PATH" "$INSTALL_APP_PATH"
open "$INSTALL_APP_PATH"

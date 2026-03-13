#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="$ROOT_DIR/build"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/PasteDock.app"

cd "$ROOT_DIR"
xcodegen generate
xcodebuild -project PasteDock.xcodeproj -scheme PasteDock -configuration Debug -derivedDataPath "$DERIVED_DATA_PATH" build
open "$APP_PATH"

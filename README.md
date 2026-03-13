# PasteDock

Clipboard recall-first menu bar app for macOS.

Primary docs:
- `docs/spec.md`
- `docs/ux-spec.md`
- `docs/wireframes.md`

## Current App

- SwiftUI/AppKit menu bar app shell
- Global shortcut presets
- Text and image clipboard monitoring with local persistence
- Left history list + right preview quick panel
- `Enter` paste now
- `Cmd+Enter` copy only
- Accessibility fallback to clipboard-only
- Settings for capture pause, retention, history size, shortcut preset, excluded apps

## Run

```bash
swift run PasteDock
```

The app launches as a menu bar utility. Open the quick panel from the menu bar or the configured global shortcut.

## Xcode App Workflow

This repo now also works like `~/Workspace/Glacier`.

```bash
xcodegen generate
open PasteDock.xcodeproj
```

Or build and launch the `.app` directly:

```bash
./scripts/run-app.sh
```

That produces `build/Build/Products/Debug/PasteDock.app` and opens it.

## Screenshot Note

`Cmd+Shift+4` saves a screenshot to a file, so PasteDock will not see it.

To copy a screenshot image to the clipboard, use:

```bash
Ctrl+Cmd+Shift+4
```

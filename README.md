# PasteDock

Clipboard recall-first menu bar app for macOS.

Primary docs:
- `docs/spec.md`
- `docs/ux-spec.md`
- `docs/wireframes.md`

## Current App

- SwiftUI/AppKit menu bar app shell
- Global shortcut presets
- Clipboard monitoring and local persistence
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

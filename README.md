# PasteDock

PasteDock is a recall-first clipboard utility for macOS. It lives in the menu bar, stores recent clipboard items locally, and restores an older item with a keyboard-first quick panel.

## Current Behavior

- Captures text and image clipboard items
- Sorts history by `last_copied_at`
- Opens a split quick panel with history on the left and preview on the right
- `Enter` pastes immediately into the previously active app
- `Cmd+Enter` copies only
- `Cmd+Delete` removes the selected item
- Persists history locally and supports excluded apps, retention, and history limits

## Build And Run

Use the repo script. It builds the app, installs it to `/Applications/PasteDock.app`, and launches that installed copy.

```bash
./scripts/run-app.sh
```

You can also open the project directly:

```bash
open PasteDock.xcodeproj
```

## Permissions

- Accessibility is required for `Paste now`
- Some apps may also trigger an Automation prompt because PasteDock falls back to `System Events` when accessibility menu paste is unavailable
- Use the installed app at `/Applications/PasteDock.app` when granting permissions so macOS keeps the permission mapping stable

## Default Controls

- `Ctrl+S`: open or close the quick panel
- `Up` / `Down`: move selection
- `Enter`: paste now
- `Cmd+Enter`: copy only
- `Cmd+Delete`: delete selected item
- `Esc`: close

## Screenshot Capture

`Cmd+Shift+4` saves a screenshot to a file, so PasteDock will not see it.

To copy a screenshot image to the clipboard instead:

```bash
Ctrl+Cmd+Shift+4
```

## Repo Layout

- `Sources/PasteDockApp`: app code
- `docs/spec.md`: current product and UX contract
- `docs/architecture.md`: implementation notes and repo structure
- `scripts/run-app.sh`: build, install, and launch helper

# PasteDock Architecture

## Build And Installation

The canonical app path is `/Applications/PasteDock.app`.

Why this matters:

- macOS permission prompts are tied to the installed app identity and path
- running transient debug builds directly from DerivedData can lead to confusing permission mismatches

`scripts/run-app.sh` is the preferred developer entrypoint because it:

1. regenerates the Xcode project when needed
2. builds the app
3. installs it to `/Applications/PasteDock.app`
4. launches the installed copy

## App Structure

- `PasteDockApp.swift`: SwiftUI app entrypoint
- `AppDelegate.swift`: sets accessory activation policy
- `AppModel.swift`: central state and orchestration
- `UI/`: menu bar, quick panel, settings, list row rendering
- `Services/`: clipboard polling, pasteboard writes, hotkey registration, persistence, accessibility, direct paste execution
- `Models/`: clipboard item model and app settings

## Core Runtime Flow

Clipboard capture flow:

1. `ClipboardMonitor` polls `NSPasteboard`
2. `AppModel` normalizes the new content
3. excluded apps and programmatic copies are filtered out
4. existing items are updated by content hash or a new item is inserted
5. items are pruned, sorted, and persisted

Quick panel flow:

1. `HotKeyService` triggers `AppModel.toggleQuickPanel()`
2. `QuickPanelController` shows the floating panel
3. `QuickPanelView` renders the list and preview
4. arrow keys update `selectedItemID`
5. `Enter` or `Cmd+Enter` routes to `AppModel.submitSelectedItem(mode:)`

Paste-now flow:

1. `PasteboardService` writes the selected item
2. `AppModel` updates item timestamps
3. `PasteExecutor` restores the previous app
4. accessibility paste is attempted first
5. `System Events` AppleScript is used as fallback

## Persistence

State is stored as JSON in:

`~/Library/Application Support/PasteDock/state.json`

Persisted state includes:

- `settings`
- `items`

The repo no longer assumes SQLite. The implemented storage is flat JSON and should be documented as such until that changes.

## Notable Implementation Decisions

- image history is stored as PNG data inside each clipboard item
- `kind` remains optional in the model for backward compatibility with older saved state
- the quick panel keeps the search field focused while arrow keys still navigate the list
- item deletion is `Cmd+Delete` so search text editing can keep using plain `Delete`

## Cleanup Rules For Future Changes

- avoid adding settings that are not wired to runtime behavior
- keep `/Applications/PasteDock.app` as the permission-bearing install target
- treat `docs/spec.md` as the product contract and update it when interaction semantics change
- prefer small service objects over expanding `AppModel` with platform-specific details

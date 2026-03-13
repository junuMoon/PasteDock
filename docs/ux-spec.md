# PasteDock UX Spec

## 1. Product Posture

PasteDock is not a general archive browser. It is a fast keyboard utility for restoring a previously copied item into the current task without breaking flow.

The product should feel like:
- Invisible while idle
- Immediate when opened
- Predictable when submitting an item
- Safe around sensitive data

## 2. Main Surfaces

### Menu Bar

- Indicates whether clipboard capture is active or paused
- Opens the quick panel
- Provides access to settings

### Quick Panel

- Primary interaction surface
- Opened by global shortcut
- Search field focused on open
- Recent items visible even with an empty query

### Settings

- Global shortcut
- Capture pause state
- History retention
- Excluded applications

## 3. Core Interaction Model

PasteDock must optimize for the browse-first loop:

1. User invokes the global shortcut
2. Quick panel opens with search focused
3. First row is preselected
4. User presses `Enter`, or navigates with arrow keys and then presses `Enter`
5. Selected item becomes the current system clipboard value
6. PasteDock pastes it into the previously active app
7. Quick panel closes

Search is a fallback path:

1. User invokes the global shortcut
2. User types a search term
3. Results filter live
4. User submits with `Enter`

## 4. Keyboard Contract

- `Global shortcut`: open quick panel
- `Up` / `Down`: move selection
- `Enter`: paste now
- `Cmd+Enter`: copy only
- `Esc`: close panel

Behavior notes:
- Search field keeps focus while arrow navigation changes the active row
- The first row should be selected by default
- The footer must explicitly label `Enter` as "Paste now" to prevent duplicate manual paste behavior

## 5. Submission Semantics

### Enter

`Enter` means:

1. Set the selected item as the active system clipboard value
2. Return focus to the previously active app
3. Paste immediately
4. Close the panel

Expected user consequence:
- If the user presses `Cmd+V` after `Enter`, the same content will be inserted again

### Cmd+Enter

`Cmd+Enter` means:

1. Set the selected item as the active system clipboard value
2. Do not paste
3. Close the panel

Expected user consequence:
- The next `Cmd+V` inserts the selected item once

## 6. Sorting and Metadata Semantics

The left list is sorted by `last_copied_at` descending.

Definitions:
- `first_copied_at`: first time the content entered clipboard history
- `last_copied_at`: last time the content became the active system clipboard value
- `last_pasted_via_pastedock_at`: last time PasteDock directly pasted the content into another app

Implications:
- Manual external copy updates `last_copied_at`
- `Enter` updates both `last_copied_at` and `last_pasted_via_pastedock_at`
- `Cmd+Enter` updates `last_copied_at` only

## 7. Left Pane Rules

The left pane is not a time table. It is a scan-optimized item list.

Each row should show:
- Primary content line
- Secondary metadata line with source app and time
- Clear selected state

The list should remain useful with an empty query because recent recovery is the primary use case.

## 8. Right Pane Rules

The right pane confirms intent before submission.

It should show:
- Full or expanded preview of the selected content
- First copied timestamp
- Last copied timestamp
- Source app

It does not need rich actions in the first usable version.

## 9. Failure Handling

If direct paste fails:
- The selected item must still remain as the active system clipboard value
- The panel should still close
- The user must be able to press `Cmd+V` manually as a fallback

The failure path should not silently discard the selection.

## 10. UX Decisions Deferred

- Pin / unpin actions
- Per-item command menu
- Rich action shortcuts beyond submit and close
- Image and file preview behavior

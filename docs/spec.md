# PasteDock Spec

## Product Position

PasteDock is a clipboard recall tool, not a clipboard database. The primary job is to restore a previously copied item with as little interruption as possible.

The default loop is:

1. Press the global shortcut
2. Look at recent items
3. Move with arrow keys if needed
4. Press `Enter`
5. Continue working in the previous app

Search exists as fallback, not as the main interaction.

## Supported Scope

Current implementation supports:

- macOS 14+
- menu bar utility with global shortcut
- text clipboard items
- image clipboard items
- local persistence
- excluded source apps
- retention and history limits
- direct paste with clipboard-only fallback

Out of scope for the current repo state:

- pinning
- tags or folders
- sync
- rich text fidelity
- file clipboard items

## Interaction Contract

Quick panel behavior:

- opens with the search field focused
- shows recent history even when the query is empty
- keeps the first visible result selected by default
- keeps keyboard selection scrolled into view

Keyboard behavior:

- `Ctrl+S`: open or close the quick panel
- `Up` / `Down`: move selection
- `Enter`: set clipboard and paste now
- `Cmd+Enter`: set clipboard only
- `Cmd+Delete`: remove selected item
- `Esc`: close without changing the clipboard

Submission behavior:

- `Enter` updates `last_copied_at`
- `Enter` also updates `last_pasted_via_pastedock_at`
- `Cmd+Enter` updates `last_copied_at` only

If direct paste fails, the selected item still becomes the current system clipboard value so the user can paste manually.

## Data Semantics

Clipboard items store:

- stable item id
- item kind (`text` or `image`)
- string content or image PNG data
- source app name and bundle id
- `first_copied_at`
- `last_copied_at`
- `last_pasted_via_pastedock_at`
- content hash for deduplication

Sorting is `last_copied_at` descending.

Repeated copies of the same content update the existing item instead of creating a duplicate row.

## Privacy Rules

- history is stored locally only
- excluded bundle ids are respected during capture
- capture can be paused
- retention and max history size can evict old items automatically

## Current Constraints

- direct paste depends on macOS permissions and target-app behavior
- settings only support preset shortcuts, not arbitrary shortcut recording
- search is substring-based, not indexed

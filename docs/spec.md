# PasteDock Spec

## 1. Product Summary

PasteDock is a desktop clipboard recall tool that keeps clipboard history in the background and helps users restore a previously copied item with minimal interruption to their current task.

Initial assumption:
- Platform: macOS 14+
- Form factor: menu bar utility with global shortcut
- Priority: fast recall, privacy, low-friction usage
- Primary interaction: open panel, move selection, press `Enter` to paste now

## 2. Problem

Users copy multiple snippets while working, then lose earlier clipboard entries as soon as a new copy action occurs. Existing workflows are fragile, especially when switching between IDEs, terminals, browsers, docs, and chat tools, and recovering an older snippet often breaks focus.

## 3. Goals

- Keep a reliable history of recent clipboard entries
- Make the common recovery path work without typing a search query
- Let users restore a past item and paste it into the active app in under 2 seconds
- Respect privacy with local-first storage and explicit exclusions
- Stay lightweight enough to run continuously in the background

## 4. Non-Goals

- Cloud sync in v1
- Team sharing or collaborative clip libraries
- OCR, screenshot editing, or document management
- Full note-taking workflow beyond quick pinning and labeling

## 5. Target Users

- Developers switching between code, terminal, browser, and docs
- Writers or researchers repeatedly reusing snippets
- Support, ops, and QA users handling repetitive text payloads

## 6. Core Use Cases

1. A user copies several code snippets and wants to restore the second one later with `Down` then `Enter`.
2. A user opens PasteDock and immediately pastes the most recent useful item without typing.
3. A user searches old clipboard text by keyword when browsing recent items is not enough.
4. A user excludes sensitive apps so copied passwords or secrets are not stored.

## 7. MVP Scope

### Included

- Clipboard monitoring in the background
- History list sorted by `last_copied_at` descending
- Split panel with history list on the left and preview on the right
- Search by text content
- `Enter`: set clipboard and paste immediately into the previously active app
- `Cmd+Enter`: set clipboard only
- Pin / unpin items as a later enhancement, not required for the first usable build
- Delete single item and clear all history
- App exclusion list
- Local persistence
- Menu bar entry and global shortcut to open the list

### Deferred

- Image and file clipboard item support
- Rich text formatting preservation
- Multi-device sync
- Custom folders, tags, and sharing
- AI-based grouping or summarization

## 8. UX Principles

- Zero setup to start capturing clipboard history
- Keyboard-first interaction should cover common actions
- Search is a fallback, not the primary path
- `Enter` should mean "paste now" everywhere in the quick panel
- Sensitive data handling must be explicit and understandable

## 9. Primary User Flow

1. User installs and launches PasteDock.
2. App requests required accessibility or clipboard-related permissions if needed.
3. PasteDock begins capturing clipboard changes in the background.
4. User opens the quick panel with a global shortcut.
5. The search field is focused, the query is empty, and the first result is preselected.
6. User either presses `Enter` immediately, moves with arrow keys, or types to search.
7. `Enter` pastes the selected item into the previously active app and closes the panel.

## 10. Functional Requirements

### Clipboard Capture

- Detect clipboard changes without duplicating identical consecutive entries
- Store plain text for MVP
- Track first-seen and last-used timestamps
- Respect maximum history size configured by the user

### History Management

- Show items in descending `last_copied_at` order
- Reusing an item via PasteDock should update its `last_copied_at`
- Support pinning pinned items later, but do not block initial implementation on it
- Allow deletion of individual entries
- Allow clearing all non-pinned history

### Search

- Filter by substring match
- Highlight matching terms in results
- Preserve responsive filtering for at least 5,000 items
- Opening the panel with an empty query must still be useful without search

### Quick Panel Interaction

- The quick panel opens with the search field focused
- The first visible row is preselected by default
- `Up` / `Down` changes selection without leaving the keyboard flow
- `Enter` sets the selected content as the current system clipboard value, pastes it into the previously active app, and closes the panel
- `Cmd+Enter` sets the selected content as the current system clipboard value without pasting
- `Esc` closes the panel without changing the clipboard
- The left pane is optimized for rapid scanning; the right pane confirms the selected content and metadata

### Privacy

- All data stored locally by default
- Allow app-level exclusion list
- Support temporary pause of clipboard capture
- Provide optional auto-expiry policy for old items

### Settings

- Configure global shortcut
- Configure history size limit
- Configure retention window
- Manage excluded applications
- Configure whether the app should prefer direct paste or copy-only by default in future versions

## 11. Non-Functional Requirements

- Launch time under 1 second on a typical modern Mac
- Search results visible within 100 ms for common queries
- Background monitoring should have minimal CPU impact when idle
- App must remain usable offline
- Storage format should be resilient across app restarts and crashes
- Open-to-paste interaction should finish in under 2 seconds for recent items

## 12. Data Model

### ClipboardItem

- `id`: stable unique identifier
- `content`: plain text payload
- `content_preview`: shortened preview string
- `source_app`: most recent non-PasteDock source app if available
- `first_copied_at`: first time the content entered clipboard history
- `last_copied_at`: last time the content became the active system clipboard value
- `last_pasted_via_pastedock_at`: last time PasteDock directly pasted the item
- `is_pinned`: boolean
- `content_hash`: used for deduplication

### Settings

- `max_history_items`
- `retention_days`
- `global_shortcut`
- `capture_paused`
- `excluded_apps`
- `default_submit_mode`

## 13. Storage Strategy

- Local database: SQLite preferred
- Store only metadata plus text content in v1
- Encrypt-at-rest is optional for v1 but should be designed as an upgrade path

Rationale:
- SQLite is simple, fast, local-first, and adequate for MVP scale.

## 14. Suggested Technical Architecture

- UI layer: native macOS app shell
- Clipboard watcher: background service or app-level monitor
- Storage layer: SQLite with lightweight data access layer
- Search: SQL `LIKE` for MVP, upgrade to FTS if needed

Candidate implementation paths:
- SwiftUI + AppKit integration for menu bar and global shortcut handling
- Tauri or Electron only if cross-platform becomes an explicit goal

## 15. Security and Privacy Considerations

- Do not store items copied from password managers when detectable
- Make excluded-app behavior easy to audit and edit
- Warn users that clipboard history may include secrets
- Allow quick purge of all saved data

## 16. Success Metrics

- Daily active usage among test users
- Number of successful restores per day
- Median time from opening PasteDock to pasting an item
- Percentage of users enabling exclusions or retention controls

## 17. Milestones

### Milestone 1: Prototype

- Clipboard capture
- Basic split-panel UI
- `Enter` paste-now action
- `Cmd+Enter` copy-only action

### Milestone 2: MVP

- Search
- Persistence
- Settings
- Exclusions
- Optional pinning if it proves necessary

### Milestone 3: Post-MVP

- Images/files support
- Rich text support
- Better indexing
- Optional sync

## 18. Open Questions

- Should v1 support only text, or text plus images?
- Is the product explicitly macOS-only, or should Windows support shape architecture early?
- Is encrypted local storage required for launch, or acceptable as a later enhancement?
- Should pinning ship in the first public version or remain deferred until the browse/restore loop is validated?

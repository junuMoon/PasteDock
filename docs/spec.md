# PasteDock Spec

## 1. Product Summary

PasteDock is a desktop clipboard history app that stores recent clipboard items, lets users search them quickly, and re-paste previous content without losing context.

Initial assumption:
- Platform: macOS 14+
- Form factor: menu bar utility with global shortcut
- Priority: fast recall, privacy, low-friction usage

## 2. Problem

Users copy multiple snippets while working, then lose earlier clipboard entries as soon as a new copy action occurs. Existing workflows are fragile, especially when switching between IDEs, terminals, browsers, docs, and chat tools.

## 3. Goals

- Keep a reliable history of recent clipboard entries
- Make past items searchable in under 2 seconds
- Allow one-keystroke re-copy or paste of previous items
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

1. A user copies several code snippets and wants to restore the second one later.
2. A user searches old clipboard text by keyword and re-copies it instantly.
3. A user pins frequently used snippets such as prompts, shell commands, or templates.
4. A user excludes sensitive apps so copied passwords or secrets are not stored.

## 7. MVP Scope

### Included

- Clipboard monitoring in the background
- History list with newest-first ordering
- Text snippet preview
- Search by text content
- Re-copy selected item to system clipboard
- Pin / unpin items
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
- Recall should be faster than manually searching old files or re-copying
- Sensitive data handling must be explicit and understandable

## 9. Primary User Flow

1. User installs and launches PasteDock.
2. App requests required accessibility or clipboard-related permissions if needed.
3. PasteDock begins capturing clipboard changes.
4. User opens the history with a menu bar click or global shortcut.
5. User filters the list by typing.
6. User selects an item to re-copy, pin, or delete.

## 10. Functional Requirements

### Clipboard Capture

- Detect clipboard changes without duplicating identical consecutive entries
- Store plain text for MVP
- Timestamp every entry
- Respect maximum history size configured by the user

### History Management

- Show recent items in descending time order
- Support pinning pinned items to a dedicated section
- Allow deletion of individual entries
- Allow clearing all non-pinned history

### Search

- Filter by substring match
- Highlight matching terms in results
- Preserve responsive filtering for at least 5,000 items

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

## 11. Non-Functional Requirements

- Launch time under 1 second on a typical modern Mac
- Search results visible within 100 ms for common queries
- Background monitoring should have minimal CPU impact when idle
- App must remain usable offline
- Storage format should be resilient across app restarts and crashes

## 12. Data Model

### ClipboardItem

- `id`: stable unique identifier
- `content`: plain text payload
- `content_preview`: shortened preview string
- `source_app`: bundle identifier if available
- `captured_at`: timestamp
- `is_pinned`: boolean
- `content_hash`: used for deduplication

### Settings

- `max_history_items`
- `retention_days`
- `global_shortcut`
- `capture_paused`
- `excluded_apps`

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
- Number of re-copies from history per day
- Median time from opening PasteDock to selecting an item
- Percentage of users enabling exclusions or retention controls

## 17. Milestones

### Milestone 1: Prototype

- Clipboard capture
- Basic list UI
- Re-copy action

### Milestone 2: MVP

- Search
- Pinning
- Persistence
- Settings
- Exclusions

### Milestone 3: Post-MVP

- Images/files support
- Rich text support
- Better indexing
- Optional sync

## 18. Open Questions

- Should v1 support only text, or text plus images?
- Is the product explicitly macOS-only, or should Windows support shape architecture early?
- Is encrypted local storage required for launch, or acceptable as a later enhancement?
- Should pinned snippets behave like a small reusable library or remain part of the same history model?

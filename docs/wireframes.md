# PasteDock Wireframes and State Flow

## 1. Screen Inventory

PasteDock v1 only needs three user-facing surfaces:

- Onboarding
- Quick panel
- Settings

The quick panel is the primary product surface and should handle almost all daily use.

## 2. Quick Panel Default State

This is the state shown when the user opens PasteDock with the global shortcut.

```text
┌─────────────────────────────────────────────────────────────┐
│ PasteDock                                                   │
│ [ Search clipboard history...                         ]     │
├──────────────────────────────┬──────────────────────────────┤
│ Recent                        │ Preview                      │
│                               │                              │
│ > npm install electron        │ npm install electron         │
│   Chrome · 10:42              │ --save-dev                   │
│                               │                              │
│   ssh prod-server             │ Metadata                     │
│   iTerm · 10:39               │ First copied  10:39          │
│                               │ Last copied   10:42          │
│   https://docs...             │ Source app    Chrome         │
│   Chrome · 10:31              │                              │
│                               │                              │
│   error stack trace...        │                              │
│   Cursor · 09:58              │                              │
├──────────────────────────────┴──────────────────────────────┤
│ Enter Paste now   Cmd+Enter Copy only   Esc Close           │
└─────────────────────────────────────────────────────────────┘
```

Default-state rules:
- Search field is focused
- Query is empty
- First row is preselected
- Left pane is scan-first
- Right pane confirms intent

## 3. Search State

This is the fallback mode when browsing recent items is not enough.

```text
┌─────────────────────────────────────────────────────────────┐
│ [ ssh                                                ]      │
├──────────────────────────────┬──────────────────────────────┤
│ Results (3)                   │ Preview                      │
│                               │                              │
│ > ssh prod-server             │ ssh prod-server              │
│   iTerm · 10:39               │                              │
│                               │ Metadata                     │
│   ssh staging                 │ First copied  ...            │
│   Warp · 어제                 │ Last copied   ...            │
│                               │ Source app    iTerm          │
│   ssh-keygen -t ed25519       │                              │
│   Terminal · 3일 전           │                              │
├──────────────────────────────┴──────────────────────────────┤
│ Enter Paste now   Cmd+Enter Copy only   Esc Close           │
└─────────────────────────────────────────────────────────────┘
```

Search-state rules:
- Typing filters the left list live
- Arrow keys keep working without leaving the text field flow
- `Enter` still means paste now
- No mode-specific submit behavior should be introduced

## 4. Empty State

Empty state should only appear before the user has copied anything that PasteDock can store.

```text
┌─────────────────────────────────────────────────────────────┐
│ [ Search clipboard history...                         ]     │
├──────────────────────────────┬──────────────────────────────┤
│ No clipboard items yet        │ Preview                      │
│                               │                              │
│ Copy text in any app and      │ Your selected item preview   │
│ PasteDock will start building │ will appear here.            │
│ your recent history.          │                              │
├──────────────────────────────┴──────────────────────────────┤
│ Esc Close                                                   │
└─────────────────────────────────────────────────────────────┘
```

## 5. Capture Paused State

The paused state should be obvious without introducing modal friction.

```text
┌─────────────────────────────────────────────────────────────┐
│ PasteDock                                   Capture Paused  │
│ [ Search clipboard history...                         ]     │
├──────────────────────────────┬──────────────────────────────┤
│ Recent items remain usable    │ Preview                      │
│ but no new clipboard entries  │                              │
│ are currently being stored.   │                              │
├──────────────────────────────┴──────────────────────────────┤
│ Enter Paste now   Cmd+Enter Copy only   Esc Close           │
└─────────────────────────────────────────────────────────────┘
```

## 6. State Flow

```text
Idle
  -> Global shortcut
Quick Panel / Default State
  -> Type query
Quick Panel / Search State
  -> Enter
Paste Now
  -> Close panel
Idle

Quick Panel / Default State
  -> Cmd+Enter
Copy Only
  -> Close panel
Idle

Quick Panel / Any State
  -> Esc
Close without change
  -> Idle
```

## 7. Event Outcomes

| Event | Clipboard | Active app | Panel | Metadata |
|---|---|---|---|---|
| Open panel | unchanged | unchanged | opens | unchanged |
| `Enter` | selected item becomes current clipboard | selected item is inserted immediately | closes | update `last_copied_at`, `last_pasted_via_pastedock_at` |
| `Cmd+Enter` | selected item becomes current clipboard | unchanged | closes | update `last_copied_at` |
| `Esc` | unchanged | unchanged | closes | unchanged |

## 8. Implementation Notes for Next Cycle

- The app should remember the previously active app before showing the panel
- Direct paste must degrade safely to clipboard-only if focus restoration fails
- The UI should not require mouse interaction for the default loop

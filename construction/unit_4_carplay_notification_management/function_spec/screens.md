# Unit 4: CarPlay Notification Management — Screens

## Screen Inventory

| Screen ID | Name | Template Type | Entry Point |
|-----------|------|---------------|-------------|
| S4.1 | Notification List | `CPListTemplate` | CarPlay root (set by Unit 3 on connect) |
| S4.2 | Notification Detail | `CPInformationTemplate` | Tap item in S4.1 |
| S4.3 | Clear All Confirmation | `CPAlertTemplate` | Tap "Clear All" in S4.1 |
| S4.4 | Empty List State | `CPListTemplate` (empty) | No notifications stored |

---

## Navigation Map

```
CarPlay Connected (root set by Unit 3)
  │
  └── S4.1 Notification List (root template)
        │
        ├── Tap item → Push: S4.2 Notification Detail
        │     │
        │     └── Back → Pop: S4.1 (list refreshes, item now marked as read)
        │
        └── Tap "Clear All" → Present: S4.3 Clear All Confirmation
              │
              ├── "Clear All" → Dismiss alert, list empties → S4.4
              └── "Cancel" → Dismiss alert, return to S4.1
```

---

## Screen Descriptions

### S4.1 — Notification List

**Purpose:** Scrollable list of all received notifications, most recent first.

**Template:** `CPListTemplate`

**Layout:**
```
┌──────────────────────────────────────┐
│  Notifications            [Clear All]│
│  ─────────────────────────────────── │
│  ● WhatsApp                    2m ago│
│    Hey, are you on your way?         │
│  ─────────────────────────────────── │
│  ● Messages                   15m ago│
│    Don't forget to pick up milk      │
│  ─────────────────────────────────── │
│    Slack                       1h ago│
│    New message in #general           │
│  ─────────────────────────────────── │
│    Gmail                       2h ago│
│    Your order has shipped            │
│  ─────────────────────────────────── │
│                                      │
└──────────────────────────────────────┘
```

**Components:**

Each list item (`CPListItem`):
| Component | Source | Notes |
|-----------|--------|-------|
| Primary text | `NotificationSummary.title` | Notification title |
| Secondary text | `NotificationSummary.sourceAppName` | App name |
| Leading image | App icon (from `SourceApp.appIcon`) | 44x44 pt, rounded |
| Detail text | Relative timestamp | e.g., "2m ago", "1h ago" |
| Unread indicator | `NotificationSummary.readStatus` | See below |

**Unread visual distinction:**
- Unread: leading dot indicator (●) or bold primary text (via `CPListItem` text styling)
- Read: no dot, normal weight text

**Navigation bar:**
- Title: "Notifications"
- Trailing button: "Clear All" (triggers S4.3)

**Empty state (S4.4):** When `notifications.count == 0`:
- Show a `CPListSection` with a single `CPListItem`:
  - Text: "No notifications yet"
  - Detail: "Notifications from your selected apps will appear here"
  - Non-selectable

**Real-time updates:**
- List refreshes automatically when:
  - `NotificationCaptured` → new item appears at top
  - `NotificationMarkedAsRead` → unread indicator removed
  - `NotificationDismissed` → item removed
  - `AllNotificationsCleared` → list empties
  - `NotificationsPruned` → old items removed

---

### S4.2 — Notification Detail

**Purpose:** Full content view of a single notification.

**Template:** `CPInformationTemplate`

**Layout:**
```
┌──────────────────────────────────────┐
│  ← Back                              │
│                                      │
│  From:     WhatsApp                  │
│  ─────────────────────────────────── │
│  Title:    Hey, are you on your way? │
│  ─────────────────────────────────── │
│  Message:  Just checking if you're   │
│            still coming to dinner    │
│            tonight. We're at the     │
│            restaurant already.       │
│  ─────────────────────────────────── │
│  Received: 2 minutes ago             │
│                                      │
└──────────────────────────────────────┘
```

**Components (`CPInformationItem` array):**

| Item | Title | Detail | Source |
|------|-------|--------|--------|
| 1 | "From" | App name | `NotificationDetail.sourceAppName` |
| 2 | "Title" | Notification title | `NotificationDetail.title` |
| 3 | "Message" | Full body text | `NotificationDetail.body` |
| 4 | "Received" | Relative timestamp | `NotificationDetail.capturedAt` (formatted) |

**Template configuration:**
- `layout: .leading` — labels aligned left
- `title`: notification title (shown in nav bar)
- Back button: standard `CPInterfaceController` pop behavior

**Side effects:**
- Opening this screen automatically marks the notification as read (`AutoMarkAsReadOnViewPolicy`).
- When returning to S4.1, the list reflects the updated read status.

---

### S4.3 — Clear All Confirmation

**Purpose:** Confirmation dialog before clearing all notifications.

**Template:** `CPAlertTemplate`

**Layout:**
```
┌──────────────────────────────────────┐
│                                      │
│   Clear all notifications?           │
│                                      │
│   ┌────────────────────────────┐     │
│   │      Clear All             │     │
│   └────────────────────────────┘     │
│   ┌────────────────────────────┐     │
│   │      Cancel                │     │
│   └────────────────────────────┘     │
│                                      │
└──────────────────────────────────────┘
```

**Components:**
| Component | Configuration |
|-----------|--------------|
| Title | `"Clear all notifications?"` |
| Action 1 | `CPAlertAction(title: "Clear All", style: .destructive)` |
| Action 2 | `CPAlertAction(title: "Cancel", style: .cancel)` |

**Behavior:**
- "Clear All": calls `managementService.clearAll()`, alert auto-dismisses, list refreshes to empty (S4.4).
- "Cancel": alert dismisses, returns to S4.1 unchanged.

---

### S4.4 — Empty List State

**Purpose:** Show when no notifications are stored (after clear all, or fresh install).

**Template:** Same `CPListTemplate` as S4.1, with empty-state content.

**Content:**
- Single section with one non-selectable `CPListItem`:
  - Text: "No notifications yet"
  - Detail text: "Notifications from your selected apps will appear here"
- "Clear All" button is hidden (or disabled) when the list is empty.

---

## CarPlay UI Constraints

| Constraint | Impact |
|-----------|--------|
| Max 12 items visible in a `CPListTemplate` section | Pagination not needed (max 100 notifications, scrollable) |
| `CPListItem` text length limited | Titles truncated by the system; body shown as secondary text |
| `CPInformationTemplate` max items | Up to 10 `CPInformationItem`s — we use 4, well within limit |
| No custom views on CarPlay | All UI through `CPTemplate` subclasses only |
| `CPAlertTemplate` max 2 actions | We use exactly 2 (Clear All + Cancel) |
| Touch/rotary knob interaction only | All interactions via tap (touch) or select (knob) |

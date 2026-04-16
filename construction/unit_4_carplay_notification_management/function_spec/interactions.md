# Unit 4: CarPlay Notification Management — Interactions

## Interaction Inventory

| ID | Interaction | Screen | Trigger | Response |
|----|-------------|--------|---------|----------|
| I4.1 | View notification list | S4.1 | CarPlay connects (root template set) | Display sorted list with unread indicators |
| I4.2 | View notification detail | S4.2 | Tap list item | Push detail template, auto-mark as read |
| I4.3 | Return to list from detail | S4.1 | Tap back button / back gesture | Pop detail, list reflects read status |
| I4.4 | Dismiss a notification | S4.1 | Swipe or trailing action on list item | Remove item from list |
| I4.5 | Mark as read (explicit) | S4.1 | Action on list item | Update read indicator |
| I4.6 | Clear all notifications | S4.3 | Tap "Clear All" button | Show confirmation → clear all → empty list |
| I4.7 | Cancel clear all | S4.3 | Tap "Cancel" | Dismiss alert, no change |
| I4.8 | List auto-refresh | S4.1 | Domain event received | Re-fetch and update list sections |

---

## Interaction Details

### I4.1 — View Notification List

**Trigger:** CarPlay connects → `CarPlayTemplateManager.setup(interfaceController:)` sets root template.

**Flow:**
1. `NotificationListTemplateBuilder.build()` creates a `CPListTemplate`.
2. `listService.fetchNotificationList()` loads all notifications as `NotificationSummary[]`.
3. Each summary is mapped to a `CPListItem`:
   - Primary text: notification title
   - Secondary text: source app name
   - Detail: relative timestamp
   - Leading image: app icon
   - Unread indicator for `readStatus == .unread`
4. Items are grouped into a single `CPListSection`.
5. Template is set as root on the `CPInterfaceController`.

**Sorting:** Most recent first (by `capturedAt` descending).

---

### I4.2 — View Notification Detail

**Trigger:** Driver taps a list item on S4.1.

**Flow:**
1. `CPListItem.handler` fires with the notification's ID.
2. `CarPlayTemplateManager.pushDetail(for: notificationId)`.
3. `NotificationDetailAppService.viewNotificationDetail(id:)`:
   a. Loads notification from repository.
   b. Applies `AutoMarkAsReadOnViewPolicy` → `notification.markAsRead()`.
   c. If newly marked as read: saves to repository, publishes `NotificationMarkedAsRead`.
   d. Returns `NotificationDetail` projection.
4. `NotificationDetailTemplateBuilder.build(for:)` creates `CPInformationTemplate`.
5. Template is pushed onto the `CPInterfaceController` stack.

**Side effect:** The notification is automatically marked as read. This is transparent to the driver — no confirmation needed.

---

### I4.3 — Return to List from Detail

**Trigger:** Driver taps the back button (system-provided by `CPInterfaceController`).

**Flow:**
1. `CPInterfaceController` pops the detail template.
2. S4.1 list is visible again.
3. The list has already been updated via the `NotificationMarkedAsRead` event subscription (I4.8).
4. The previously unread item now shows as read (no dot/no bold).

---

### I4.4 — Dismiss a Notification

**Trigger:** Driver performs a dismiss action on a list item.

**Implementation approach:**
CarPlay `CPListItem` does not natively support swipe-to-delete. Options:
1. **`CPListItem` with a handler that shows a mini-menu** — use `CPListItem.handler` to present a `CPActionSheetTemplate` with "View" / "Dismiss" options.
2. **Long-press / secondary action** — some CarPlay vehicles support this via rotary knob press.

**Recommended: Action sheet on item selection** (most compatible across CarPlay vehicles):

**Flow (action sheet approach):**
1. Driver taps a list item.
2. A `CPActionSheetTemplate` appears with options:
   - "View Details" → I4.2
   - "Dismiss" → deletes the notification
3. If "Dismiss" is selected:
   a. `NotificationManagementAppService.dismiss(id:)`.
   b. `notification.dismiss()` → `repository.delete(id)`.
   c. `NotificationDismissed` event published.
   d. List refreshes (I4.8) — item disappears.

**Alternative (direct tap = view, with "Clear All" for bulk):** If the action sheet feels too heavy, tap could go directly to detail (I4.2) and dismiss is only available via "Clear All" (I4.6). This simplifies the interaction at the cost of per-item dismiss.

---

### I4.5 — Mark as Read (Explicit)

**Trigger:** Included in the action sheet from I4.4 (if action sheet approach is used), or happens automatically via I4.2.

**Flow (if explicit):**
1. Action sheet includes "Mark as Read" option.
2. `NotificationManagementAppService.markAsRead(id:)`.
3. `notification.markAsRead()` → `repository.save()`.
4. `NotificationMarkedAsRead` event published.
5. List refreshes — unread indicator removed.

**Note:** This interaction is optional if auto-mark-as-read on detail view (I4.2) is sufficient. The domain supports both explicit and implicit marking.

---

### I4.6 — Clear All Notifications

**Trigger:** Driver taps "Clear All" button in S4.1's navigation bar.

**Flow:**
1. `CarPlayTemplateManager.showClearAllConfirmation()`.
2. `ClearAllConfirmationBuilder.build()` creates `CPAlertTemplate`.
3. Template is presented modally via `interfaceController.presentTemplate()`.
4. Driver sees: "Clear all notifications?" with [Clear All] and [Cancel].
5. If "Clear All" tapped:
   a. `NotificationManagementAppService.clearAll()`.
   b. `repository.deleteAll()`.
   c. `AllNotificationsCleared` event published.
   d. Alert auto-dismisses.
   e. List refreshes to empty state (S4.4).
6. If "Cancel" tapped:
   a. Alert dismisses.
   b. List unchanged.

---

### I4.7 — Cancel Clear All

**Trigger:** Driver taps "Cancel" on S4.3.

**Flow:** `CPAlertTemplate` dismisses automatically. No domain operation. List unchanged.

---

### I4.8 — List Auto-Refresh

**Trigger:** Any domain event that affects the notification list.

**Events that trigger refresh:**
| Event | Effect on List |
|-------|---------------|
| `NotificationCaptured` | New item appears at top |
| `NotificationMarkedAsRead` | Unread indicator removed from item |
| `NotificationDismissed` | Item removed |
| `AllNotificationsCleared` | All items removed → empty state |
| `NotificationsPruned` | Oldest items removed |

**Flow:**
1. `NotificationListAppService.observeListChanges()` returns a merged Combine publisher.
2. On each event, `CarPlayTemplateManager.refreshList()` is called.
3. `NotificationListTemplateBuilder.refresh()` re-fetches all summaries from the query service.
4. `CPListTemplate.updateSections()` replaces the list content.

**Debouncing:** If multiple events arrive rapidly (e.g., burst of notifications), refresh is debounced with a short delay (e.g., 300ms) to avoid excessive re-rendering.

---

## CarPlay-Specific Interaction Constraints

| Constraint | Mitigation |
|-----------|------------|
| No swipe gestures on all CarPlay vehicles | Use action sheet or direct tap-to-detail instead of swipe-to-dismiss |
| Rotary knob: select = tap, scroll = rotate | All interactions work with select (tap) + scroll |
| Limited screen real estate | Truncated text, minimal info per list item |
| Driver distraction guidelines | Minimal interaction depth (1-2 taps to reach any action), auto-mark-as-read reduces actions needed |
| `CPListTemplate` max items per update | Apple recommends < 20 items for performance; our cap of 100 works but list may feel long — consider showing only most recent 20 with "Show More" |

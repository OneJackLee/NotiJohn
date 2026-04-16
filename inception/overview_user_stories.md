# NotiJohn - User Stories

## Personas

| Persona | Description |
|---------|-------------|
| **Driver** | A user actively driving with their iPhone connected to a CarPlay-compatible vehicle. Interacts with the app exclusively through the CarPlay UI. Prioritizes hands-free, glanceable, and audio-based interactions. |
| **User** | The same person when interacting with the iPhone companion app (outside of CarPlay). Configures settings, selects apps, and manages preferences. |

---

## Epic 1: iPhone Companion App (Settings & Configuration)

> The iPhone app serves as the configuration hub. There is no notification list on the iPhone — only settings and setup.

### US-1.1: Select Apps to Monitor
**As a** user,
**I want to** see a list of all installed apps that send notifications and select which ones I want to monitor,
**so that** I only receive relevant notifications on CarPlay.

**Acceptance Criteria:**
- The app displays a list of all installed apps that have notification permissions
- Each app has a toggle to enable/disable monitoring
- Selected apps are persisted across app restarts
- Changes take effect immediately without requiring an app restart

### US-1.2: Onboarding and Permission Setup
**As a** user,
**I want to** be guided through the initial setup (granting notification access and app selection),
**so that** the app is ready to use when I connect to CarPlay.

**Acceptance Criteria:**
- On first launch, the app presents a step-by-step onboarding flow
- The onboarding requests notification access permission
- The onboarding guides the user to select at least one app to monitor
- The user can skip optional steps and complete setup later

---

## Epic 2: Notification Listening & Capture

> The core background service that captures notifications from selected apps and stores them for CarPlay display.

### US-2.1: Listen to Notifications from Selected Apps
**As a** user,
**I want** the app to listen for incoming notifications from my selected apps in the background,
**so that** no relevant notification is missed while I am driving.

**Acceptance Criteria:**
- The app captures notifications only from user-selected apps
- Notification listening works while the app is in the background
- Notifications from non-selected apps are ignored
- If the user changes app selection, the change takes effect immediately

### US-2.2: Store Received Notifications
**As a** user,
**I want** received notifications to be stored locally on my device,
**so that** I can browse them later in the CarPlay notification list.

**Acceptance Criteria:**
- Each captured notification stores: source app name, app icon, title, body, and timestamp
- Notifications persist locally until explicitly dismissed by the user
- Storage does not grow unbounded — oldest notifications are pruned after a reasonable limit (e.g., 100 notifications)

### US-2.3: Capture Notifications While Connected to CarPlay
**As a** driver,
**I want** notifications received while connected to CarPlay to be captured and forwarded to the CarPlay UI in real time,
**so that** I am informed immediately.

**Acceptance Criteria:**
- When CarPlay is connected, new notifications appear on the CarPlay UI within seconds
- Notifications captured while CarPlay is not connected are stored and available in the list when CarPlay reconnects

---

## Epic 3: CarPlay UI — Notification Display & Announcement

> How incoming notifications are presented and announced on the CarPlay screen.

### US-3.1: Display Incoming Notification on CarPlay
**As a** driver,
**I want** incoming notifications to be displayed on the CarPlay screen,
**so that** I can see at a glance who sent the notification and what it says.

**Acceptance Criteria:**
- A notification banner/card appears on the CarPlay screen when a new notification arrives
- The banner shows: source app name, notification title, and a preview of the body text
- The banner auto-dismisses after a configurable duration
- The banner does not obstruct critical CarPlay navigation elements

### US-3.2: Announce Notification via Text-to-Speech
**As a** driver,
**I want** incoming notifications to be read aloud through my car speakers using text-to-speech,
**so that** I can stay informed without taking my eyes off the road.

**Acceptance Criteria:**
- When TTS is enabled, the app reads aloud the notification using the iOS TTS API
- The announcement includes: source app name, notification title, and body
- TTS audio plays through the car's speakers via the CarPlay audio session
- If multiple notifications arrive in quick succession, they are queued and read sequentially
- TTS does not interrupt active navigation voice guidance (or resumes after)

### US-3.3: Suppress Duplicate Announcements
**As a** driver,
**I want** duplicate or repeated notifications to not be announced multiple times,
**so that** I am not distracted by redundant alerts.

**Acceptance Criteria:**
- If the same notification (same app, title, and body) arrives within a short time window, only the first occurrence is announced
- Duplicates are still stored in the notification list but not re-announced

---

## Epic 4: CarPlay UI — Notification List & Management

> The CarPlay screen where users can browse, manage, and interact with received notifications.

### US-4.1: View Notification List on CarPlay
**As a** driver,
**I want to** view a scrollable list of all received notifications on the CarPlay screen,
**so that** I can catch up on notifications I may have missed.

**Acceptance Criteria:**
- The CarPlay app presents a list view of received notifications
- Notifications are sorted by most recent first
- Each list item shows: source app name, notification title, and timestamp
- The list is scrollable using CarPlay-compatible controls (rotary knob / touch)

### US-4.2: View Notification Detail on CarPlay
**As a** driver,
**I want to** tap on a notification in the list to see its full content,
**so that** I can read the complete notification body.

**Acceptance Criteria:**
- Tapping a list item opens a detail view
- The detail view shows: source app name, app icon, title, full body text, and timestamp
- The detail view has a back button to return to the list
- Opening a notification detail automatically marks it as read

### US-4.3: Distinguish Read vs Unread Notifications
**As a** driver,
**I want** unread notifications to be visually distinct from read ones in the list,
**so that** I can quickly identify which notifications are new.

**Acceptance Criteria:**
- Unread notifications have a distinct visual indicator (e.g., bold text, dot indicator)
- Once a notification is marked as read, the visual indicator is removed
- The visual distinction is clear and glanceable on a car display

### US-4.4: Mark Notification as Read
**As a** driver,
**I want to** mark a notification as read,
**so that** I can track which notifications I have already reviewed.

**Acceptance Criteria:**
- The user can mark a notification as read from the list (e.g., swipe action or context action)
- Opening a notification detail also marks it as read (see US-4.2)
- Read status persists until the notification is dismissed

### US-4.5: Dismiss a Notification
**As a** driver,
**I want to** dismiss a notification from the list,
**so that** I can remove notifications I no longer need.

**Acceptance Criteria:**
- The user can dismiss a notification from the list via a CarPlay-compatible action
- Dismissed notifications are permanently removed from the list
- Dismissing is a distinct action from marking as read — a notification can be read but not dismissed

### US-4.6: Clear All Notifications
**As a** driver,
**I want to** clear all notifications from the list at once,
**so that** I can start fresh without dismissing them one by one.

**Acceptance Criteria:**
- A "Clear All" action is available in the notification list view
- Tapping it removes all notifications from the list
- A confirmation step prevents accidental clearing

---

## Epic 5: System & Permissions

> System-level behaviors, permissions, and CarPlay connectivity.

### US-5.1: Request Notification Access Permission
**As a** user,
**I want** the app to request permission to access notifications from other apps,
**so that** it can capture and display them on CarPlay.

**Acceptance Criteria:**
- The app requests notification access permission via the iOS system prompt
- If permission is denied, the app explains why it is needed and directs the user to Settings
- The app gracefully handles permission being revoked at any time

### US-5.2: Connect to CarPlay Automatically
**As a** driver,
**I want** the app to appear on the CarPlay screen automatically when my iPhone connects to a CarPlay-compatible vehicle,
**so that** I don't have to manually launch it.

**Acceptance Criteria:**
- The app registers as a CarPlay-compatible app and appears on the CarPlay home screen
- When the iPhone connects to CarPlay, the app's CarPlay UI is available immediately
- When the iPhone disconnects from CarPlay, the app continues capturing notifications in the background

### US-5.3: Handle CarPlay Connection and Disconnection
**As a** driver,
**I want** the app to gracefully handle CarPlay connection changes (connect/disconnect),
**so that** I don't lose any notifications during transitions.

**Acceptance Criteria:**
- Notifications received while CarPlay is disconnected are stored and appear in the list upon reconnection
- The app does not crash or lose state when CarPlay connects or disconnects mid-use
- TTS announcements stop immediately when CarPlay disconnects

---

## User Story Summary

| Epic | Story Count |
|------|-------------|
| 1 — iPhone Companion App (Settings & Configuration) | 2 |
| 2 — Notification Listening & Capture | 3 |
| 3 — CarPlay UI — Notification Display & Announcement | 3 |
| 4 — CarPlay UI — Notification List & Management | 6 |
| 5 — System & Permissions | 3 |
| **Total** | **17** |

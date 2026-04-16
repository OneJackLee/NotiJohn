# Unit 2: Notification Engine (Listening, Capture & Storage)

## Overview

This unit is the core background service responsible for capturing notifications from user-selected apps, filtering out irrelevant ones, and persisting them locally. It acts as the data producer for the CarPlay UI units. This unit has no user-facing UI of its own.

**Persona:** User (indirectly — this unit operates in the background on behalf of the user)

---

## User Stories

### US-2.1: Listen to Notifications from Selected Apps

**As a** user,
**I want** the app to listen for incoming notifications from my selected apps in the background,
**so that** no relevant notification is missed while I am driving.

**Acceptance Criteria:**
- The app captures notifications only from user-selected apps
- Notification listening works while the app is in the background
- Notifications from non-selected apps are ignored
- If the user changes app selection, the change takes effect immediately

---

### US-2.2: Store Received Notifications

**As a** user,
**I want** received notifications to be stored locally on my device,
**so that** I can browse them later in the CarPlay notification list.

**Acceptance Criteria:**
- Each captured notification stores: source app name, app icon, title, body, and timestamp
- Notifications persist locally until explicitly dismissed by the user
- Storage does not grow unbounded — oldest notifications are pruned after a reasonable limit (e.g., 100 notifications)

---

### US-2.3: Capture Notifications While Connected to CarPlay

**As a** driver,
**I want** notifications received while connected to CarPlay to be captured and forwarded to the CarPlay UI in real time,
**so that** I am informed immediately.

**Acceptance Criteria:**
- When CarPlay is connected, new notifications appear on the CarPlay UI within seconds
- Notifications captured while CarPlay is not connected are stored and available in the list when CarPlay reconnects

---

## Dependencies

| Direction | Unit | Description |
|-----------|------|-------------|
| Inbound ← | Unit 1 (iPhone Companion App) | Consumes the "selected apps" list to filter which notifications to capture. |
| Outbound → | Unit 3 (CarPlay Presentation) | Pushes real-time notification events for display and TTS announcement. |
| Outbound → | Unit 4 (CarPlay Notification Management) | Writes to the notification store that Unit 4 reads from. |

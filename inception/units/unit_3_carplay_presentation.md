# Unit 3: CarPlay Presentation (Display, TTS & Connection Lifecycle)

## Overview

This unit handles the real-time, event-driven CarPlay experience: displaying incoming notification banners, reading notifications aloud via text-to-speech, suppressing duplicates, and managing the CarPlay connection lifecycle (auto-connect, disconnect handling).

**Persona:** Driver (interacting through the CarPlay UI while driving)

---

## User Stories

### US-3.1: Display Incoming Notification on CarPlay

**As a** driver,
**I want** incoming notifications to be displayed on the CarPlay screen,
**so that** I can see at a glance who sent the notification and what it says.

**Acceptance Criteria:**
- A notification banner/card appears on the CarPlay screen when a new notification arrives
- The banner shows: source app name, notification title, and a preview of the body text
- The banner auto-dismisses after a configurable duration
- The banner does not obstruct critical CarPlay navigation elements

---

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

---

### US-3.3: Suppress Duplicate Announcements

**As a** driver,
**I want** duplicate or repeated notifications to not be announced multiple times,
**so that** I am not distracted by redundant alerts.

**Acceptance Criteria:**
- If the same notification (same app, title, and body) arrives within a short time window, only the first occurrence is announced
- Duplicates are still stored in the notification list but not re-announced

---

### US-5.2: Connect to CarPlay Automatically

**As a** driver,
**I want** the app to appear on the CarPlay screen automatically when my iPhone connects to a CarPlay-compatible vehicle,
**so that** I don't have to manually launch it.

**Acceptance Criteria:**
- The app registers as a CarPlay-compatible app and appears on the CarPlay home screen
- When the iPhone connects to CarPlay, the app's CarPlay UI is available immediately
- When the iPhone disconnects from CarPlay, the app continues capturing notifications in the background

---

### US-5.3: Handle CarPlay Connection and Disconnection

**As a** driver,
**I want** the app to gracefully handle CarPlay connection changes (connect/disconnect),
**so that** I don't lose any notifications during transitions.

**Acceptance Criteria:**
- Notifications received while CarPlay is disconnected are stored and appear in the list upon reconnection
- The app does not crash or lose state when CarPlay connects or disconnects mid-use
- TTS announcements stop immediately when CarPlay disconnects

---

## Dependencies

| Direction | Unit | Description |
|-----------|------|-------------|
| Inbound ← | Unit 2 (Notification Engine) | Receives real-time notification events for display and TTS. |
| Sibling ↔ | Unit 4 (CarPlay Notification Management) | Both operate on CarPlay but on different screens/flows. Minimal direct coupling. |

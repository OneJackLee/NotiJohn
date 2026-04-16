# Unit 4: CarPlay Notification Management (List, Detail & Actions)

## Overview

This unit covers the CarPlay screens where drivers browse, inspect, and manage stored notifications. It is state-driven (CRUD operations on notification records) rather than event-driven, making it distinct from Unit 3's real-time presentation concerns.

**Persona:** Driver (interacting through the CarPlay UI while driving)

---

## User Stories

### US-4.1: View Notification List on CarPlay

**As a** driver,
**I want to** view a scrollable list of all received notifications on the CarPlay screen,
**so that** I can catch up on notifications I may have missed.

**Acceptance Criteria:**
- The CarPlay app presents a list view of received notifications
- Notifications are sorted by most recent first
- Each list item shows: source app name, notification title, and timestamp
- The list is scrollable using CarPlay-compatible controls (rotary knob / touch)

---

### US-4.2: View Notification Detail on CarPlay

**As a** driver,
**I want to** tap on a notification in the list to see its full content,
**so that** I can read the complete notification body.

**Acceptance Criteria:**
- Tapping a list item opens a detail view
- The detail view shows: source app name, app icon, title, full body text, and timestamp
- The detail view has a back button to return to the list
- Opening a notification detail automatically marks it as read

---

### US-4.3: Distinguish Read vs Unread Notifications

**As a** driver,
**I want** unread notifications to be visually distinct from read ones in the list,
**so that** I can quickly identify which notifications are new.

**Acceptance Criteria:**
- Unread notifications have a distinct visual indicator (e.g., bold text, dot indicator)
- Once a notification is marked as read, the visual indicator is removed
- The visual distinction is clear and glanceable on a car display

---

### US-4.4: Mark Notification as Read

**As a** driver,
**I want to** mark a notification as read,
**so that** I can track which notifications I have already reviewed.

**Acceptance Criteria:**
- The user can mark a notification as read from the list (e.g., swipe action or context action)
- Opening a notification detail also marks it as read (see US-4.2)
- Read status persists until the notification is dismissed

---

### US-4.5: Dismiss a Notification

**As a** driver,
**I want to** dismiss a notification from the list,
**so that** I can remove notifications I no longer need.

**Acceptance Criteria:**
- The user can dismiss a notification from the list via a CarPlay-compatible action
- Dismissed notifications are permanently removed from the list
- Dismissing is a distinct action from marking as read — a notification can be read but not dismissed

---

### US-4.6: Clear All Notifications

**As a** driver,
**I want to** clear all notifications from the list at once,
**so that** I can start fresh without dismissing them one by one.

**Acceptance Criteria:**
- A "Clear All" action is available in the notification list view
- Tapping it removes all notifications from the list
- A confirmation step prevents accidental clearing

---

## Dependencies

| Direction | Unit | Description |
|-----------|------|-------------|
| Inbound ← | Unit 2 (Notification Engine) | Reads from the notification store that Unit 2 writes to. |
| Sibling ↔ | Unit 3 (CarPlay Presentation) | Both operate on CarPlay but on different screens/flows. Minimal direct coupling. |

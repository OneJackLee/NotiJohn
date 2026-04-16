# Unit 1: iPhone Companion App (Settings, Onboarding & Permissions)

## Overview

This unit covers the iPhone-side experience: first-launch onboarding, notification permission acquisition, and app selection for monitoring. There is no notification list on the iPhone — only settings and setup.

**Persona:** User (interacting with the iPhone companion app outside of CarPlay)

---

## User Stories

### US-1.1: Select Apps to Monitor

**As a** user,
**I want to** see a list of all installed apps that send notifications and select which ones I want to monitor,
**so that** I only receive relevant notifications on CarPlay.

**Acceptance Criteria:**
- The app displays a list of all installed apps that have notification permissions
- Each app has a toggle to enable/disable monitoring
- Selected apps are persisted across app restarts
- Changes take effect immediately without requiring an app restart

---

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

### US-5.1: Request Notification Access Permission

**As a** user,
**I want** the app to request permission to access notifications from other apps,
**so that** it can capture and display them on CarPlay.

**Acceptance Criteria:**
- The app requests notification access permission via the iOS system prompt
- If permission is denied, the app explains why it is needed and directs the user to Settings
- The app gracefully handles permission being revoked at any time

---

## Dependencies

| Direction | Unit | Description |
|-----------|------|-------------|
| Outbound → | Unit 2 (Notification Engine) | Produces the "selected apps" list that Unit 2 consumes to filter notifications. |

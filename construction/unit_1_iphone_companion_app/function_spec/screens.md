# Unit 1: iPhone Companion App — Screens

## Screen Inventory

| Screen ID | Name | Type | Entry Point |
|-----------|------|------|-------------|
| S1.1 | Welcome | Onboarding step | App first launch |
| S1.2 | Permission Request | Onboarding step | After S1.1 |
| S1.3 | App Selection (Onboarding) | Onboarding step | After S1.2 |
| S1.4 | Setup Complete | Onboarding step | After S1.3 |
| S1.5 | Settings (App Selection) | Main screen | Post-onboarding app launch |
| S1.6 | Permission Denied Recovery | Modal/inline | When permission is denied |

---

## Navigation Map

```
App Launch
  │
  ├── First Launch (isOnboardingComplete == false)
  │     │
  │     └── Onboarding Flow (linear, non-reversible progression)
  │           │
  │           S1.1 Welcome
  │             │ [Continue]
  │             ▼
  │           S1.2 Permission Request
  │             │ [Grant] → iOS system prompt
  │             │ [Permission denied] → S1.6 inline guidance
  │             │ [Continue]
  │             ▼
  │           S1.3 App Selection (Onboarding)
  │             │ [Select apps + Continue] or [Skip]
  │             ▼
  │           S1.4 Setup Complete
  │             │ [Get Started]
  │             ▼
  │           → S1.5 Settings (main screen)
  │
  └── Returning Launch (isOnboardingComplete == true)
        │
        └── S1.5 Settings (App Selection)
```

---

## Screen Descriptions

### S1.1 — Welcome

**Purpose:** Introduce the app and set expectations.

**Layout:**
```
┌─────────────────────────────────┐
│                                 │
│         [App Logo/Icon]         │
│                                 │
│          NotiJohn               │
│                                 │
│   Your notifications,           │
│   on CarPlay.                   │
│                                 │
│   NotiJohn captures             │
│   notifications from your       │
│   favorite apps and displays    │
│   them on CarPlay while you     │
│   drive.                        │
│                                 │
│                                 │
│   ┌─────────────────────────┐   │
│   │      Continue           │   │
│   └─────────────────────────┘   │
│                                 │
└─────────────────────────────────┘
```

**Components:**
- App icon/logo (image, centered)
- App name heading (large title)
- Description text (body, multi-line, centered)
- "Continue" button (primary action, full width)

**Data:** None — static content.

---

### S1.2 — Permission Request

**Purpose:** Request notification access permission from the user.

**Layout:**
```
┌─────────────────────────────────┐
│                                 │
│       [Bell/Shield Icon]        │
│                                 │
│   Notification Access           │
│                                 │
│   NotiJohn needs permission     │
│   to read notifications from    │
│   your apps so it can display   │
│   them on CarPlay.              │
│                                 │
│   ┌─────────────────────────┐   │
│   │   Allow Notifications   │   │
│   └─────────────────────────┘   │
│                                 │
│   ── or ──                      │
│                                 │
│   [Permission denied state]:    │
│   ┌─────────────────────────┐   │
│   │   Open Settings         │   │
│   └─────────────────────────┘   │
│   Permission was denied. Tap    │
│   above to enable in Settings.  │
│                                 │
│   ┌─────────────────────────┐   │
│   │      Continue           │   │
│   └─────────────────────────┘   │
│                                 │
└─────────────────────────────────┘
```

**Components:**
- Icon (SF Symbol: `bell.badge.fill` or `shield.checkered`)
- Heading ("Notification Access")
- Explanation text
- "Allow Notifications" button (triggers iOS system prompt) — shown when `status == .notDetermined`
- Permission denied recovery block — shown when `status == .denied`:
  - "Open Settings" button (deep-links to app settings)
  - Explanation text
- "Continue" button (advances to next step)

**Data:**
- `permissionStatus: PermissionStatus` from `NotificationPermissionService`

**States:**
| State | UI |
|-------|-----|
| `notDetermined` | Show "Allow Notifications" button |
| `granted` | Show checkmark + success message, auto-advance after delay |
| `denied` | Show "Open Settings" button + recovery guidance |

---

### S1.3 — App Selection (Onboarding)

**Purpose:** Guide user to select which apps to monitor. Reuses the same component as S1.5 settings.

**Layout:**
```
┌─────────────────────────────────┐
│                                 │
│   Select Apps to Monitor        │
│                                 │
│   Choose which apps' notifs     │
│   will appear on CarPlay.       │
│                                 │
│   ┌─────────────────────────┐   │
│   │ [icon] WhatsApp     [·] │   │
│   │ [icon] Messages     [·] │   │
│   │ [icon] Telegram     [ ] │   │
│   │ [icon] Slack        [ ] │   │
│   │ [icon] Gmail        [ ] │   │
│   │ [icon] ...          [ ] │   │
│   └─────────────────────────┘   │
│                                 │
│   ┌─────────────────────────┐   │
│   │      Continue           │   │
│   └─────────────────────────┘   │
│   ┌─────────────────────────┐   │
│   │      Skip               │   │
│   └─────────────────────────┘   │
│                                 │
└─────────────────────────────────┘
```

**Components:**
- Heading ("Select Apps to Monitor")
- Subtitle text
- Scrollable app list:
  - Each row: app icon (32x32), app display name, toggle switch
  - Sorted alphabetically by display name
- "Continue" button (primary)
- "Skip" button (secondary, text-only) — skips app selection, can be done later

**Data:**
- `installedApps: [AppInfo]` from `InstalledAppDiscoveryService`
- `monitoredApps: [MonitoredApp]` from `MonitoredAppSettings`

---

### S1.4 — Setup Complete

**Purpose:** Confirm setup is done, transition to the main app.

**Layout:**
```
┌─────────────────────────────────┐
│                                 │
│        [Checkmark Icon]         │
│                                 │
│     You're All Set!             │
│                                 │
│   Connect your iPhone to        │
│   CarPlay and your selected     │
│   notifications will appear     │
│   automatically.                │
│                                 │
│   You can change your app       │
│   selection anytime in          │
│   Settings.                     │
│                                 │
│   ┌─────────────────────────┐   │
│   │     Get Started         │   │
│   └─────────────────────────┘   │
│                                 │
└─────────────────────────────────┘
```

**Components:**
- Checkmark icon (SF Symbol: `checkmark.circle.fill`, large, green)
- Heading ("You're All Set!")
- Body text (instructions)
- "Get Started" button (primary, navigates to Settings screen)

**Data:** None — static content.

---

### S1.5 — Settings (App Selection)

**Purpose:** Post-onboarding main screen. Allows the user to manage which apps are monitored.

**Layout:**
```
┌─────────────────────────────────┐
│  Settings                       │
│                                 │
│  MONITORED APPS                 │
│  ┌─────────────────────────┐    │
│  │ [icon] WhatsApp     [·] │    │
│  │ [icon] Messages     [·] │    │
│  │ [icon] Telegram     [ ] │    │
│  │ [icon] Slack        [·] │    │
│  │ [icon] Gmail        [ ] │    │
│  └─────────────────────────┘    │
│                                 │
│  NOTIFICATION ACCESS            │
│  ┌─────────────────────────┐    │
│  │ Status: Granted    [>]  │    │
│  └─────────────────────────┘    │
│  (or "Denied — tap to fix")    │
│                                 │
└─────────────────────────────────┘
```

**Components:**
- Navigation title: "Settings"
- Section: "Monitored Apps"
  - Scrollable list of apps with toggle switches (same component as S1.3)
  - Each toggle fires `enableApp` / `disableApp` immediately
- Section: "Notification Access"
  - Status row showing current permission status
  - If denied: tappable row that deep-links to iOS Settings

**Data:**
- `monitoredApps: [MonitoredApp]` — reactive, updates on toggle
- `permissionStatus: PermissionStatus` — checked on `onAppear`

---

### S1.6 — Permission Denied Recovery (Inline)

Not a separate screen — rendered inline within S1.2 and S1.5 when `permissionStatus == .denied`.

**Components:**
- Warning icon (SF Symbol: `exclamationmark.triangle.fill`, yellow)
- Explanation: "Notification access is required for NotiJohn to work. Please enable it in Settings."
- "Open Settings" button → `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)`

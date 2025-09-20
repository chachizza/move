# Move

**Move** is a simple, beautiful iPhone app that reminds you to do short exercises throughout the day.  
It uses local notifications and randomized scheduling to keep things fun and engaging.

## Features
- Add, edit, and disable exercises with emoji icons.
- Schedule fixed times or use random windows with quiet hours.
- Local notifications with quick actions: **Done**, **Snooze**, **Swap**.
- Logs completions and streaks.
- All data stored locally (privacy first).

## Requirements
- Xcode 15+
- iOS 17 or later
- Swift 5.10+
- SwiftData enabled

## Setup
1. Open `Move.xcodeproj` in Xcode.
2. Under **Signing & Capabilities**, select your Apple Developer Team and set a unique Bundle ID (e.g. `com.yourname.move`).
3. Run on your device.
4. On first launch, allow Notifications.
5. In Settings, tap **Schedule test reminders** to verify notifications.

## Architecture Overview
- **SwiftData** persistence with models for `Exercise`, `ScheduleSettings`, and `Completion`. The container is created in `AppStartup` and injected via `.modelContainer`. ([SwiftData docs](https://developer.apple.com/documentation/swiftdata))
- **SchedulingService** computes a 7-day rolling plan, respecting spacing, quiet hours, and weekends, and issues `UNCalendarNotificationTrigger` requests. ([UserNotifications docs](https://developer.apple.com/documentation/usernotifications))
- **NotificationService** wraps `UNUserNotificationCenter`, registers custom actions, and routes quick-action responses back into SwiftData.
- **SwiftUI Tabs** provide Home, Exercises, Schedule, History, and Settings views. Shared styling lives in `Design/` with reusable components.

## Notifications & Scheduling
- Reminders are generated when schedule settings change or when the app launches.
- Quick actions provide **Done** (logs completion), **Snooze** (+15 minutes), and **Swap** (picks another exercise while preserving schedule time).
- Quiet hours are respected even when users configure overlapping windows; random windows degrade gracefully if misconfigured (documented in code comments).

## Testing
Run the unit suite from the command line:

```bash
xcodebuild test -project Move.xcodeproj -scheme Move -destination 'platform=iOS Simulator,name=iPhone 15'
```

Tests cover scheduling spacing and rotation logic via `SchedulingService.Planner` helpers.

## Privacy
All data is stored on your device. No analytics or cloud syncing in MVP.  
Future roadmap may include iCloud sync or HealthKit, with explicit consent.

## Roadmap
1. Lock screen widgets
2. History charts
3. watchOS companion app
4. iCloud sync

## App Store Checklist
- Provide marketing screenshots (home, schedule, notifications).
- Confirm `NSUserNotificationUsageDescription` explains reminders.
- Verify notification quick actions on device.
- Run TestFlight build on multiple devices with Dynamic Type enabled and reduced motion.

---

## License
For personal use. Not affiliated with Apple or any fitness program.

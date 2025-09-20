# Move Project Agents

The Move scaffold was produced by a virtual cross-functional team. Each agent’s remit, major decisions, and forward-looking notes are captured here for quick reference.

## Product Agent
- **Mission**: Clarify MVP scope, user problems, and non-goals.
- **Key Outcomes**:
  - Committed to a day-structuring exercise reminder app targeting iOS 17+ phones.
  - Locked the MVP feature list (Exercises CRUD, Schedule builder, randomized reminders, History, Settings with privacy guardrails).
  - Identified out-of-scope-but-tracked features (widgets, charts, watchOS, iCloud Sync) documented in the roadmap.
- **Future Work**: Validate streak mechanics with real users; gather feedback on quick-action usefulness and scheduling flexibility edge cases.

## iOS Architect Agent
- **Mission**: Choose frameworks and project structure for App Store readiness.
- **Key Outcomes**:
  - Selected SwiftUI + SwiftData + UserNotifications stack; prepared `AppStartup` to centralize dependency wiring.
  - Defined module layout (`App/`, `Features/`, `Services/`, `Models/`, `Design/`, `Utils/`, `Tests/`).
  - Established SwiftData models with `@Model` annotations and fallbacks noted in code comments.
  - Ensured seven-day scheduling horizon and action handling live in actor-isolated services to avoid race conditions.
- **Future Work**: Explore SwiftData migrations for v1.1, consider feature flags for optional frameworks (e.g., Core Data fallback, HealthKit).

## UX/UI Agent
- **Mission**: Craft a minimal, playful interface that respects accessibility.
- **Key Outcomes**:
  - Delivered tabbed navigation covering Home, Exercises, Schedule, History, Settings.
  - Applied color tokens (`MovePrimary`, `MoveAccent`, etc.) and reusable components (`CardView`, `PrimaryButtonStyle`, `EmptyStateView`).
  - Ensured Dynamic Type and VoiceOver-friendly layouts (labels, toggles, accessibility labels).
  - Home dashboard surfaces streaks, upcoming reminders, and “Do Now” quick action.
- **Future Work**: Add animation variants respecting Reduce Motion; design App Icon and widget assets; prepare marketing screenshots.

## Data & Notifications Agent
- **Mission**: Model user data, implement seeding, scheduling, and notification flows.
- **Key Outcomes**:
  - Authored `SchedulingService` planner with quiet hours, weekend toggle, spacing, randomization, and quick actions (Done/Snooze/Swap).
  - Created `NotificationService` bridging quick actions back into SwiftData.
  - Built `SeedDataService` and `SeedExercises.json` for first-run population; added export/import service for local backups.
  - Documented assumptions (e.g., random windows require `endHour > startHour`) inline.
- **Future Work**: Monitor notification authorization states for provisional/critical alerts; add background refresh hooks to reconcile pending requests when app returns to foreground.

## QA Agent
- **Mission**: Validate scheduling, randomization, and data integrity via automated tests.
- **Key Outcomes**:
  - Added unit tests for fixed-time honoring, minimum spacing, least-recent exercise weighting, and quiet-hour exclusion.
  - Provided CLI invocation guidance in README (`xcodebuild test -project Move.xcodeproj -scheme Move ...`).
  - Highlighted sandbox limitations encountered in CI (i.e., derived-data permission issues) for follow-up.
- **Future Work**: Expand tests to cover snooze/swap behaviors with mocked `UNNotificationRequest`s; integrate UI tests once stable.

## Docs Agent
- **Mission**: Produce developer-facing documentation and compliance notes.
- **Key Outcomes**:
  - Authored `README.md` with setup steps, architecture overview, privacy stance, testing command, and App Store checklist.
  - Captured roadmap items and licensing posture.
  - Recorded color palette, notification usage description, and seeding data references.
- **Future Work**: Prepare CONTRIBUTING.md for future collaborators; draft privacy policy text for App Store submission.

---
Need adjustments or deeper dives per agent? Open an issue or tag the relevant section above.

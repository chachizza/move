import Foundation
import SwiftData
import UserNotifications

/// Central application environment coordinating persistence, notifications, and scheduling.
/// https://developer.apple.com/documentation/swiftdata/modelcontainer
@MainActor
final class AppStartup: ObservableObject {
    let container: ModelContainer
    let notificationService: NotificationService
    let schedulingService: SchedulingService
    let seedDataService: SeedDataService
    let exportImportService: ExportImportService
    let streakCalculator = StreakCalculator()

    @Published private(set) var notificationsAuthorized: Bool = false
    @Published private(set) var configurationCompleted = false

    private var hasConfigured = false

    init() {
        container = Self.makeContainer()

        let notificationService = NotificationService(container: container)
        let schedulingService = SchedulingService(container: container, notificationService: notificationService)
        notificationService.attach(schedulingService: schedulingService)

        self.notificationService = notificationService
        self.schedulingService = schedulingService
        self.seedDataService = SeedDataService(container: container)
        self.exportImportService = ExportImportService(container: container)
    }

    /// Performs one-time configuration: data seeding, notification set up, and initial scheduling.
    func configureIfNeeded() async {
        guard !hasConfigured else { return }
        hasConfigured = true

        await withTaskGroup(of: Void.self) { group in
            group.addTask { [seedDataService] in
                await seedDataService.preloadExercisesIfNeeded()
            }
            group.addTask { [seedDataService] in
                await seedDataService.ensureScheduleDefaults()
            }
        }
        notificationService.registerCategories()
        await refreshNotificationAuthorizationState()

        Task(priority: .background) { [weak self] in
            guard let self else { return }
            do {
                try await self.schedulingService.refreshSchedule()
            } catch {
                print("Scheduling error during bootstrap: \(error)")
            }
        }
        configurationCompleted = true
    }

    func refreshNotificationAuthorizationState() async {
        notificationsAuthorized = await notificationService.currentAuthorizationStatus()
    }

    func requestNotifications() async {
        do {
            try await notificationService.requestAuthorization()
            await refreshNotificationAuthorizationState()
        } catch {
            print("Notification authorization failed: \(error)")
        }
    }

    func scheduleTestReminder() async {
        do {
            try await schedulingService.scheduleTestReminder()
        } catch {
            print("Test reminder scheduling failed: \(error)")
        }
    }

    private static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: Exercise.self, ScheduleSettings.self, Completion.self)
        } catch {
            print("SwiftData container creation failed: \(error). Attempting to reset store and retry.")
            resetPersistentStore()
            do {
                return try ModelContainer(for: Exercise.self, ScheduleSettings.self, Completion.self)
            } catch {
                fatalError("Failed to create SwiftData container after reset: \(error)")
            }
        }
    }

    private static func resetPersistentStore() {
        guard let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        let fileManager = FileManager.default
        let base = supportURL.appendingPathComponent("default.store")
        let candidates = [base,
                          supportURL.appendingPathComponent("default.store-wal"),
                          supportURL.appendingPathComponent("default.store-shm")]

        for url in candidates {
            do {
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                }
            } catch {
                print("Failed to remove stale store file at \(url): \(error)")
            }
        }
    }
}

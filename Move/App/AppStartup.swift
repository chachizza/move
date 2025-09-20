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
        do {
            container = try ModelContainer(for: Exercise.self, ScheduleSettings.self, Completion.self)
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }

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

        await seedDataService.preloadExercisesIfNeeded()
        await seedDataService.ensureScheduleDefaults()
        notificationService.registerCategories()
        await refreshNotificationAuthorizationState()

        do {
            try await schedulingService.refreshSchedule()
        } catch {
            print("Scheduling error during bootstrap: \(error)")
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
}

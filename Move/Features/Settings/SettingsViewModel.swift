import Foundation
import SwiftData

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var notificationsAuthorized = false
    @Published var lastExportURL: URL?
    @Published var alertMessage: String?
    @Published private(set) var pendingReminderCount: Int = 0

    private weak var app: AppStartup?
    private var isConfigured = false

    func configure(app: AppStartup) async {
        guard !isConfigured else {
            await refreshAuthorizationState()
            await refreshPendingReminderCount()
            return
        }
        self.app = app
        isConfigured = true
        await refreshAuthorizationState()
        await refreshPendingReminderCount()
    }

    func refreshAuthorizationState() async {
        guard let app else { return }
        notificationsAuthorized = await app.notificationService.currentAuthorizationStatus()
    }

    func refreshPendingReminderCount() async {
        guard let app else { return }
        let summaries = await app.schedulingService.upcomingReminderSummaries()
        pendingReminderCount = summaries.count
    }

    func regenerateSchedule() async {
        guard let app else { return }
        do {
            try await app.schedulingService.refreshSchedule()
            await refreshPendingReminderCount()
            setAlert("Upcoming 7-day schedule regenerated.")
        } catch {
            print("Manual schedule regeneration failed: \(error)")
            setAlert("Regeneration failed: \(error.localizedDescription)")
        }
    }

    func requestNotifications() async {
        guard let app else { return }
        do {
            try await app.notificationService.requestAuthorization()
            await refreshAuthorizationState()
            await refreshPendingReminderCount()
            setAlert(notificationsAuthorized ? "Notifications enabled." : "Notifications are still disabled.")
        } catch {
            print("Notification request failed: \(error)")
            setAlert("Notification request failed: \(error.localizedDescription)")
        }
    }

    func scheduleTestReminder() async {
        guard let app else { return }
        let authorized = await app.notificationService.currentAuthorizationStatus()
        guard authorized else {
            setAlert("Enable notifications for Move in Settings > Notifications before scheduling reminders.")
            return
        }
        do {
            try await app.schedulingService.scheduleTestReminder()
            await refreshPendingReminderCount()
            setAlert("Test reminder scheduled for about one minute from now. Leave the app to see it.")
        } catch {
            print("Failed to schedule test reminder: \(error)")
            setAlert("Failed to schedule test reminder: \(error.localizedDescription)")
        }
    }

    func exportData() async {
        guard let app else { return }
        do {
            let url = try await MainActor.run { try app.exportImportService.exportData() }
            lastExportURL = url
            setAlert("Export created at \(url.lastPathComponent).")
        } catch {
            print("Data export failed: \(error)")
            setAlert("Data export failed: \(error.localizedDescription)")
        }
    }

    func importData(from url: URL) async {
        guard let app else { return }
        do {
            try await MainActor.run { try app.exportImportService.importData(from: url) }
            try await app.schedulingService.refreshSchedule()
            await refreshPendingReminderCount()
            setAlert("Import succeeded and schedule refreshed.")
        } catch {
            print("Import failed: \(error)")
            setAlert("Import failed: \(error.localizedDescription)")
        }
    }

    func resetData(context: ModelContext) async {
        guard let app else { return }
        do {
            try context.deleteAll(of: Exercise.self)
            try context.deleteAll(of: Completion.self)
            try context.deleteAll(of: ScheduleSettings.self)
            try context.save()
            await app.seedDataService.preloadExercisesIfNeeded()
            await app.seedDataService.ensureScheduleDefaults()
            try await app.schedulingService.refreshSchedule()
            await refreshPendingReminderCount()
            setAlert("Data reset complete. Default exercises restored.")
        } catch {
            print("Reset failed: \(error)")
            setAlert("Reset failed: \(error.localizedDescription)")
        }
    }

    private func setAlert(_ text: String) {
        alertMessage = nil
        alertMessage = text
    }
}

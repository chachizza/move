import Foundation
import SwiftData
import UserNotifications

/// Wraps `UNUserNotificationCenter` to manage authorization, categories, and action handling.
/// https://developer.apple.com/documentation/usernotifications/unusernotificationcenter
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private let container: ModelContainer
    private var schedulingService: SchedulingService?
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init(container: ModelContainer) {
        self.container = container
        super.init()
        center.delegate = self
    }

    func attach(schedulingService: SchedulingService) {
        self.schedulingService = schedulingService
    }

    func registerCategories() {
        let done = UNNotificationAction(identifier: NotificationAction.done.rawValue,
                                         title: NotificationAction.done.title,
                                         options: [.foreground])
        let snooze = UNNotificationAction(identifier: NotificationAction.snooze.rawValue,
                                           title: NotificationAction.snooze.title,
                                           options: [])
        let swap = UNNotificationAction(identifier: NotificationAction.swap.rawValue,
                                         title: NotificationAction.swap.title,
                                         options: [.foreground])
        let category = UNNotificationCategory(identifier: "MOVE_REMINDER",
                                              actions: [done, snooze, swap],
                                              intentIdentifiers: [],
                                              options: [.customDismissAction])
        center.setNotificationCategories([category])
    }

    func requestAuthorization() async throws {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        let granted = try await center.requestAuthorization(options: options)
        guard granted else {
            throw NotificationError.authorizationDenied
        }
    }

    func currentAuthorizationStatus() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    func replacePendingRequests(with requests: [UNNotificationRequest]) async {
        center.removeAllPendingNotificationRequests()
        for request in requests {
            await add(request: request)
        }
    }

    func add(request: UNNotificationRequest) async {
        do {
            try await center.add(request)
        } catch {
            print("Failed to schedule notification \(request.identifier): \(error)")
        }
    }

    func pendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    func removePending(withIdentifiers identifiers: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        Task {
            await handle(response: response)
            completionHandler()
        }
    }

    private func handle(response: UNNotificationResponse) async {
        guard let info = response.notification.request.content.userInfo as? [String: Any],
              let exerciseIDString = info[NotificationPayloadKey.exerciseID] as? String,
              let exerciseID = UUID(uuidString: exerciseIDString),
              let scheduledDateString = info[NotificationPayloadKey.scheduledDate] as? String,
              let scheduledDate = isoFormatter.date(from: scheduledDateString) else {
            return
        }

        switch response.actionIdentifier {
        case NotificationAction.done.rawValue:
            await logCompletion(exerciseID: exerciseID)
            if let service = schedulingService {
                try? await service.refreshSchedule()
            }
        case NotificationAction.snooze.rawValue:
            await schedulingService?.snoozeReminder(for: exerciseID, from: scheduledDate)
        case NotificationAction.swap.rawValue:
            await schedulingService?.swapExercise(at: scheduledDate, excluding: exerciseID)
        default:
            break
        }
    }

    private func logCompletion(exerciseID: UUID) async {
        let context = ModelContext(container)
        context.autosaveEnabled = true
        do {
            let completion = Completion(exerciseID: exerciseID)
            context.insert(completion)
            try context.save()
        } catch {
            print("Failed to log completion from notification: \(error)")
        }
    }
}

enum NotificationError: Error {
    case authorizationDenied
}

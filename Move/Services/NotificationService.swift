import Foundation
import SwiftData
@preconcurrency import UserNotifications

/// Wraps `UNUserNotificationCenter` to manage authorization, categories, and action handling.
/// https://developer.apple.com/documentation/usernotifications/unusernotificationcenter
@MainActor
final class NotificationService: NSObject {
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
        let category = UNNotificationCategory(identifier: Constants.Notifications.categoryIdentifier,
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
        center.removeAllDeliveredNotifications()
        try? await center.setBadgeCount(0)
        guard !requests.isEmpty else { return }
        for request in requests {
            await add(request: request)
        }
    }

    func add(request: UNNotificationRequest) async {
        await withCheckedContinuation { continuation in
            let identifier = request.identifier
            center.add(request) { error in
                if let error {
                    print("Failed to schedule notification \(identifier): \(error)")
                }
                continuation.resume()
            }
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

    private func handle(response: UNNotificationResponse) async {
        guard let info = response.notification.request.content.userInfo as? [String: Any],
              let exerciseIDString = info[Constants.Notifications.PayloadKeys.exerciseID] as? String,
              let exerciseID = UUID(uuidString: exerciseIDString),
              let scheduledDateString = info[Constants.Notifications.PayloadKeys.scheduledDate] as? String,
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
            try? await center.setBadgeCount(0)
        } catch {
            print("Failed to log completion from notification: \(error)")
        }
    }
}

@MainActor
extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.handle(response: response)
            completionHandler()
        }
    }
}

enum NotificationError: Error {
    case authorizationDenied
}

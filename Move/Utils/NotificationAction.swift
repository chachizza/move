import Foundation

enum NotificationAction: String, CaseIterable {
    case done = "MOVE_ACTION_DONE"
    case snooze = "MOVE_ACTION_SNOOZE"
    case swap = "MOVE_ACTION_SWAP"

    var title: String {
        switch self {
        case .done: return "Done"
        case .snooze: return "Snooze 15m"
        case .swap: return "Swap"
        }
    }
}

enum NotificationPayloadKey {
    static let exerciseID = "exerciseID"
    static let scheduledDate = "scheduledDate"
    static let requestID = "requestID"
}

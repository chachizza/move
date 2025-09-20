import Foundation
import SwiftData

@Model
final class Completion {
    @Attribute(.unique) var id: UUID
    var exerciseID: UUID
    var timestamp: Date

    init(id: UUID = UUID(), exerciseID: UUID, timestamp: Date = .now) {
        self.id = id
        self.exerciseID = exerciseID
        self.timestamp = timestamp
    }
}

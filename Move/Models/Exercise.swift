import Foundation
import SwiftData

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var emoji: String
    var category: String
    var durationMinutes: Int
    var difficulty: Int
    var instructions: String?
    var isActive: Bool

    init(id: UUID = UUID(), name: String, emoji: String, category: String, durationMinutes: Int, difficulty: Int, instructions: String? = nil, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.category = category
        self.durationMinutes = durationMinutes
        self.difficulty = difficulty
        self.instructions = instructions
        self.isActive = isActive
    }
}

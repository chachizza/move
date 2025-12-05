import Foundation
import SwiftData

/// Serializes and restores Move data to JSON for manual export/import workflows.
@MainActor
final class ExportImportService {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func exportData() throws -> URL {
        let context = ModelContext(container)
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let settings = try context.fetch(FetchDescriptor<ScheduleSettings>()).first
        let completions = try context.fetch(FetchDescriptor<Completion>())

        let payload = BackupPayload(exercises: exercises.map(ExerciseDTO.init),
                                    schedule: settings.map(ScheduleSettingsDTO.init),
                                    completions: completions.map(CompletionDTO.init))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MoveExport-\(ISO8601DateFormatter().string(from: Date())).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    func importData(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let payload = try decoder.decode(BackupPayload.self, from: data)
        let context = ModelContext(container)
        context.autosaveEnabled = true

        try purgeExistingData(in: context)

        payload.exercises.forEach { context.insert($0.model) }
        if let schedule = payload.schedule?.model {
            context.insert(schedule)
        }
        payload.completions.forEach { context.insert($0.model) }
        try context.save()
    }

    private func purgeExistingData(in context: ModelContext) throws {
        try context.deleteAll(of: Exercise.self)
        try context.deleteAll(of: ScheduleSettings.self)
        try context.deleteAll(of: Completion.self)
    }
}

private struct BackupPayload: Codable {
    var exercises: [ExerciseDTO]
    var schedule: ScheduleSettingsDTO?
    var completions: [CompletionDTO]
}

private struct ExerciseDTO: Codable {
    let id: UUID
    let name: String
    let emoji: String
    let category: String
    let durationMinutes: Int
    let difficulty: Int
    let instructions: String?
    let isActive: Bool

    init(exercise: Exercise) {
        id = exercise.id
        name = exercise.name
        emoji = exercise.emoji
        category = exercise.category
        durationMinutes = exercise.durationMinutes
        difficulty = exercise.difficulty
        instructions = exercise.instructions
        isActive = exercise.isActive
    }

    var model: Exercise {
        Exercise(id: id,
                 name: name,
                 emoji: emoji,
                 category: category,
                 durationMinutes: durationMinutes,
                 difficulty: difficulty,
                 instructions: instructions,
                 isActive: isActive)
    }
}

private struct ScheduleSettingsDTO: Codable {
    let useFixedTimes: Bool
    let fixedSlots: [ScheduleSlotDTO]
    let useRandomWindows: Bool
    let randomStartHour: Int
    let randomEndHour: Int
    let maxRemindersPerDay: Int
    let minSpacingMinutes: Int
    let quietStartHour: Int
    let quietEndHour: Int
    let skipWeekends: Bool

    init(settings: ScheduleSettings) {
        useFixedTimes = settings.useFixedTimes
        fixedSlots = settings.fixedSlots.map(ScheduleSlotDTO.init)
        useRandomWindows = settings.useRandomWindows
        randomStartHour = settings.randomStartHour
        randomEndHour = settings.randomEndHour
        maxRemindersPerDay = settings.maxRemindersPerDay
        minSpacingMinutes = settings.minSpacingMinutes
        quietStartHour = settings.quietStartHour
        quietEndHour = settings.quietEndHour
        skipWeekends = settings.skipWeekends
    }

    var model: ScheduleSettings {
        ScheduleSettings(useFixedTimes: useFixedTimes,
                         fixedSlots: fixedSlots.map { $0.model },
                         useRandomWindows: useRandomWindows,
                         randomStartHour: randomStartHour,
                         randomEndHour: randomEndHour,
                         maxRemindersPerDay: maxRemindersPerDay,
                         minSpacingMinutes: minSpacingMinutes,
                         quietStartHour: quietStartHour,
                         quietEndHour: quietEndHour,
                         skipWeekends: skipWeekends)
    }
}

private struct ScheduleSlotDTO: Codable {
    let hour: Int?
    let minute: Int?
    let exerciseID: UUID?

    init(slot: ScheduleSlot) {
        hour = slot.hour
        minute = slot.minute
        exerciseID = slot.exerciseID
    }

    var model: ScheduleSlot {
        ScheduleSlot(hour: hour, minute: minute, exerciseID: exerciseID)
    }
}

private struct CompletionDTO: Codable {
    let id: UUID
    let exerciseID: UUID
    let timestamp: Date

    init(completion: Completion) {
        id = completion.id
        exerciseID = completion.exerciseID
        timestamp = completion.timestamp
    }

    var model: Completion {
        Completion(id: id, exerciseID: exerciseID, timestamp: timestamp)
    }
}

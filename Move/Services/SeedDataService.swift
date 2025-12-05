import Foundation
import SwiftData

/// Handles initial data population shipped with the app bundle.
@MainActor
final class SeedDataService {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func preloadExercisesIfNeeded() async {
        let context = ModelContext(container)
        context.autosaveEnabled = true

        let descriptor = FetchDescriptor<Exercise>()
        let existing = (try? context.fetch(descriptor)) ?? []
        
        // 1. Remove old default exercises
        let oldDefaults = ["Neck Stretch", "Shoulder Rolls", "Calf Raises", "Plank", "Posture Reset", "Eye 20-20-20"]
        let toRemove = existing.filter { oldDefaults.contains($0.name) }
        
        if !toRemove.isEmpty {
            print("Removing \(toRemove.count) old default exercises.")
            toRemove.forEach { context.delete($0) }
            try? context.save()
        }

        // 2. Load new seeds and insert if missing
        let seeds = SeedDataLoader.loadExercises()
        // Re-fetch to get current state after deletion
        let current = (try? context.fetch(descriptor)) ?? []
        
        for seed in seeds {
            // Check by ID or Name to avoid duplicates
            if !current.contains(where: { $0.id == seed.id || $0.name == seed.name }) {
                print("Seeding new exercise: \(seed.name)")
                context.insert(seed)
            }
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to save seeded exercises: \(error)")
        }
    }

    func ensureScheduleDefaults() async {
        let context = ModelContext(container)
        context.autosaveEnabled = true
        let descriptor = FetchDescriptor<ScheduleSettings>()
        if let existing = try? context.fetch(descriptor), existing.isEmpty {
            let settings = ScheduleSettings(useFixedTimes: true,
                                            fixedSlots: [ScheduleSlot(hour: 10, minute: 0),
                                                         ScheduleSlot(hour: 14, minute: 0),
                                                         ScheduleSlot(hour: 16, minute: 0)],
                                            useRandomWindows: true,
                                            randomStartHour: 9,
                                            randomEndHour: 18,
                                            maxRemindersPerDay: 4,
                                            minSpacingMinutes: 60,
                                            quietStartHour: 21,
                                            quietEndHour: 7,
                                            skipWeekends: false)
            context.insert(settings)
            do {
                try context.save()
            } catch {
                print("Failed to persist default settings: \(error)")
            }
        }
    }
}

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
        guard existing.isEmpty else { return }

        let seeds = SeedDataLoader.loadExercises()
        seeds.forEach { context.insert($0) }
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
            var morning = DateComponents()
            morning.hour = 10
            var afternoon = DateComponents()
            afternoon.hour = 14
            var late = DateComponents()
            late.hour = 16
            let settings = ScheduleSettings(useFixedTimes: true,
                                            fixedTimes: [morning, afternoon, late],
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

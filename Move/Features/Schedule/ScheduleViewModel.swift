import Foundation
import SwiftData

@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published var useFixedTimes: Bool = true
    @Published var fixedTimes: [DateComponents] = []
    @Published var useRandomWindows: Bool = true
    @Published var randomStartHour: Int = 9
    @Published var randomEndHour: Int = 18
    @Published var maxRemindersPerDay: Int = 4
    @Published var minSpacingMinutes: Int = 60
    @Published var quietStartHour: Int = 21
    @Published var quietEndHour: Int = 7
    @Published var skipWeekends: Bool = false

    private var settings: ScheduleSettings?

    func configure(with settings: ScheduleSettings?) {
        guard !isConfigured else {
            self.settings = settings
            return
        }
        self.settings = settings
        useFixedTimes = settings?.useFixedTimes ?? useFixedTimes
        fixedTimes = settings?.fixedTimes ?? defaultTimes
        useRandomWindows = settings?.useRandomWindows ?? useRandomWindows
        randomStartHour = settings?.randomStartHour ?? randomStartHour
        randomEndHour = settings?.randomEndHour ?? randomEndHour
        maxRemindersPerDay = settings?.maxRemindersPerDay ?? maxRemindersPerDay
        minSpacingMinutes = settings?.minSpacingMinutes ?? minSpacingMinutes
        quietStartHour = settings?.quietStartHour ?? quietStartHour
        quietEndHour = settings?.quietEndHour ?? quietEndHour
        skipWeekends = settings?.skipWeekends ?? skipWeekends
        isConfigured = true
    }

    func addFixedTime() {
        var components = DateComponents()
        components.hour = 10
        components.minute = 0
        fixedTimes.append(components)
    }

    func updateFixedTime(at index: Int, to date: Date, calendar: Calendar) {
        var components = calendar.dateComponents([.hour, .minute], from: date)
        components.second = 0
        if index < fixedTimes.count {
            fixedTimes[index] = components
        }
    }

    func removeFixedTime(at offsets: IndexSet) {
        fixedTimes.remove(atOffsets: offsets)
    }

    func save(modelContext: ModelContext, schedulingService: SchedulingService) async {
        let target = settings ?? ScheduleSettings()
        target.useFixedTimes = useFixedTimes
        target.fixedTimes = normalizedFixedTimes()
        target.useRandomWindows = useRandomWindows
        let normalizedStart = min(randomStartHour, randomEndHour - 1)
        let normalizedEnd = max(randomEndHour, normalizedStart + 1)
        target.randomStartHour = max(0, normalizedStart)
        target.randomEndHour = min(23, normalizedEnd)
        target.maxRemindersPerDay = max(1, maxRemindersPerDay)
        target.minSpacingMinutes = max(15, minSpacingMinutes)
        target.quietStartHour = quietStartHour
        target.quietEndHour = quietEndHour
        target.skipWeekends = skipWeekends

        if settings == nil {
            modelContext.insert(target)
            settings = target
        }

        do {
            try modelContext.save()
            try await schedulingService.refreshSchedule()
        } catch {
            print("Failed to save schedule settings: \(error)")
        }
    }

    private func normalizedFixedTimes() -> [DateComponents] {
        let filtered = fixedTimes.filter { $0.hour != nil }
        if filtered.isEmpty {
            return defaultTimes
        }
        return filtered
    }

    private var isConfigured = false

    private var defaultTimes: [DateComponents] {
        var morning = DateComponents()
        morning.hour = 10
        var afternoon = DateComponents()
        afternoon.hour = 14
        var late = DateComponents()
        late.hour = 16
        return [morning, afternoon, late]
    }
}

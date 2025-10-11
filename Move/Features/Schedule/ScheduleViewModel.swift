import Foundation
import SwiftData

@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published var useFixedTimes: Bool = true
    @Published var fixedSlots: [ScheduleSlot] = []
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
        fixedSlots = normalizedInitialSlots(from: settings)
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
        var slot = ScheduleSlot()
        slot.hour = 10
        slot.minute = 0
        fixedSlots.append(slot)
    }

    func updateFixedTime(at index: Int, to date: Date, calendar: Calendar) {
        var components = calendar.dateComponents([.hour, .minute], from: date)
        components.second = 0
        if index < fixedSlots.count {
            fixedSlots[index].hour = components.hour
            fixedSlots[index].minute = components.minute
        }
    }

    func removeFixedTime(at offsets: IndexSet) {
        fixedSlots.remove(atOffsets: offsets)
    }

    func updateExercise(at index: Int, to exerciseID: UUID?) {
        guard index < fixedSlots.count else { return }
        fixedSlots[index].exerciseID = exerciseID
    }

    func save(modelContext: ModelContext, schedulingService: SchedulingService) async {
        let target = settings ?? ScheduleSettings()
        target.useFixedTimes = useFixedTimes
        target.fixedSlots = normalizedSlots()
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

    private func normalizedSlots() -> [ScheduleSlot] {
        let filtered = fixedSlots.filter { $0.hour != nil }
        if filtered.isEmpty {
            return defaultSlots
        }
        return filtered
    }

    private func normalizedInitialSlots(from settings: ScheduleSettings?) -> [ScheduleSlot] {
        if let slots = settings?.fixedSlots, !slots.isEmpty {
            return slots
        }
        return defaultSlots
    }

    private var isConfigured = false

    private var defaultSlots: [ScheduleSlot] {
        [ScheduleSlot(hour: 10, minute: 0),
         ScheduleSlot(hour: 14, minute: 0),
         ScheduleSlot(hour: 16, minute: 0)]
    }
}

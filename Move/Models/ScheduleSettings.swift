import Foundation
import SwiftData

@Model
final class ScheduleSettings {
    var useFixedTimes: Bool
    private var fixedSlotsData: Data
    var useRandomWindows: Bool
    var randomStartHour: Int
    var randomEndHour: Int
    var maxRemindersPerDay: Int
    var minSpacingMinutes: Int
    var quietStartHour: Int
    var quietEndHour: Int
    var skipWeekends: Bool

    init(
        useFixedTimes: Bool = true,
        fixedSlots: [ScheduleSlot] = [],
        useRandomWindows: Bool = false,
        randomStartHour: Int = 9,
        randomEndHour: Int = 17,
        maxRemindersPerDay: Int = 3,
        minSpacingMinutes: Int = 60,
        quietStartHour: Int = 21,
        quietEndHour: Int = 7,
        skipWeekends: Bool = false
    ) {
        self.useFixedTimes = useFixedTimes
        self.fixedSlotsData = Self.encode(slots: fixedSlots)
        self.useRandomWindows = useRandomWindows
        self.randomStartHour = randomStartHour
        self.randomEndHour = randomEndHour
        self.maxRemindersPerDay = maxRemindersPerDay
        self.minSpacingMinutes = minSpacingMinutes
        self.quietStartHour = quietStartHour
        self.quietEndHour = quietEndHour
        self.skipWeekends = skipWeekends
    }

    var fixedSlots: [ScheduleSlot] {
        get { Self.decode(data: fixedSlotsData) }
        set { fixedSlotsData = Self.encode(slots: newValue) }
    }

    private static func encode(slots: [ScheduleSlot]) -> Data {
        guard !slots.isEmpty else { return Data() }
        let encoder = JSONEncoder()
        return (try? encoder.encode(slots)) ?? Data()
    }

    private static func decode(data: Data) -> [ScheduleSlot] {
        guard !data.isEmpty else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([ScheduleSlot].self, from: data)) ?? []
    }
}

struct ScheduleSlot: Codable, Hashable {
    var hour: Int?
    var minute: Int?
    var exerciseID: UUID?

    init(hour: Int? = nil, minute: Int? = nil, exerciseID: UUID? = nil) {
        self.hour = hour
        self.minute = minute
        self.exerciseID = exerciseID
    }

    init(components: DateComponents, exerciseID: UUID? = nil) {
        self.hour = components.hour
        self.minute = components.minute
        self.exerciseID = exerciseID
    }

    func asDateComponents(defaultHour: Int = 9) -> DateComponents {
        var components = DateComponents()
        components.hour = hour ?? defaultHour
        components.minute = minute ?? 0
        return components
    }
}

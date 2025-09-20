import Foundation
import SwiftData

@Model
final class ScheduleSettings {
    var useFixedTimes: Bool
    var fixedTimes: [DateComponents]
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
        fixedTimes: [DateComponents] = [],
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
        self.fixedTimes = fixedTimes
        self.useRandomWindows = useRandomWindows
        self.randomStartHour = randomStartHour
        self.randomEndHour = randomEndHour
        self.maxRemindersPerDay = maxRemindersPerDay
        self.minSpacingMinutes = minSpacingMinutes
        self.quietStartHour = quietStartHour
        self.quietEndHour = quietEndHour
        self.skipWeekends = skipWeekends
    }
}

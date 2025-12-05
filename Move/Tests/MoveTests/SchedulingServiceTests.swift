import XCTest
@testable import Move

final class SchedulingServiceTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testFixedTimesHonored() throws {
        let settings = ScheduleSettings(useFixedTimes: true,
                                        fixedSlots: [slot(hour: 9), slot(hour: 13), slot(hour: 17)],
                                        useRandomWindows: false,
                                        randomStartHour: 9,
                                        randomEndHour: 18,
                                        maxRemindersPerDay: 4,
                                        minSpacingMinutes: 60,
                                        quietStartHour: 21,
                                        quietEndHour: 7,
                                        skipWeekends: false)
        let exercises = sampleExercises(count: 3)
        let planner = SchedulingService.Planner(settings: settings,
                                                exercises: exercises,
                                                completions: [],
                                                calendar: calendar,
                                                now: referenceDate())
        let plan = planner.generatePlan(days: 1)
        XCTAssertEqual(plan.count, 3)
        let times = plan.map { calendar.component(.hour, from: $0.fireDate) }
        XCTAssertEqual(times, [9, 13, 17])
    }

    func testMinSpacingApplied() throws {
        var slotList = [slot(hour: 9), slot(hour: 10), slot(hour: 11)]
        slotList.append(slot(hour: 12))
        let settings = ScheduleSettings(useFixedTimes: true,
                                        fixedSlots: slotList,
                                        useRandomWindows: false,
                                        randomStartHour: 9,
                                        randomEndHour: 12,
                                        maxRemindersPerDay: 4,
                                        minSpacingMinutes: 120,
                                        quietStartHour: 22,
                                        quietEndHour: 6,
                                        skipWeekends: false)
        let exercises = sampleExercises(count: 4)
        let planner = SchedulingService.Planner(settings: settings,
                                                exercises: exercises,
                                                completions: [],
                                                calendar: calendar,
                                                now: referenceDate())
        let plan = planner.generatePlan(days: 1)
        XCTAssertEqual(plan.count, 2, "Only reminders respecting 120 minute spacing should remain")
        let hours = plan.map { calendar.component(.hour, from: $0.fireDate) }
        XCTAssertEqual(hours, [9, 11])
    }

    func testRotationPrefersLeastRecent() {
        let exercises = sampleExercises(count: 3)
        let completions = [Completion(exerciseID: exercises[0].id, timestamp: referenceDate().addingTimeInterval(-86400 * 3)),
                           Completion(exerciseID: exercises[1].id, timestamp: referenceDate().addingTimeInterval(-86400))]
        let settings = ScheduleSettings(useFixedTimes: true,
                                        fixedSlots: [slot(hour: 9), slot(hour: 10), slot(hour: 11)],
                                        useRandomWindows: false,
                                        randomStartHour: 9,
                                        randomEndHour: 18,
                                        maxRemindersPerDay: 3,
                                        minSpacingMinutes: 30,
                                        quietStartHour: 22,
                                        quietEndHour: 6,
                                        skipWeekends: false)
        let planner = SchedulingService.Planner(settings: settings,
                                                exercises: exercises,
                                                completions: completions,
                                                calendar: calendar,
                                                now: referenceDate())
        let plan = planner.generatePlan(days: 1)
        XCTAssertEqual(plan.count, 3)
        // Expect exercise[2] (never completed) to appear first.
        XCTAssertEqual(plan.first?.exercise.id, exercises[2].id)
    }

    func testFixedSlotRespectsChosenExercise() {
        let exercises = sampleExercises(count: 3)
        let customSlotExercise = exercises[1]
        let settings = ScheduleSettings(useFixedTimes: true,
                                        fixedSlots: [slot(hour: 9, exerciseID: customSlotExercise.id)],
                                        useRandomWindows: false,
                                        randomStartHour: 9,
                                        randomEndHour: 18,
                                        maxRemindersPerDay: 1,
                                        minSpacingMinutes: 30,
                                        quietStartHour: 22,
                                        quietEndHour: 6,
                                        skipWeekends: false)
        let planner = SchedulingService.Planner(settings: settings,
                                                exercises: exercises,
                                                completions: [],
                                                calendar: calendar,
                                                now: referenceDate())
        let plan = planner.generatePlan(days: 1)
        XCTAssertEqual(plan.first?.exercise.id, customSlotExercise.id)
    }

    private func slot(hour: Int, minute: Int = 0, exerciseID: UUID? = nil) -> ScheduleSlot {
        ScheduleSlot(hour: hour, minute: minute, exerciseID: exerciseID)
    }

    private func sampleExercises(count: Int) -> [Exercise] {
        (0..<count).map { index in
            Exercise(name: "Exercise \(index)",
                     emoji: "💪",
                     category: "General",
                     durationMinutes: 2,
                     difficulty: 1,
                     instructions: nil,
                     isActive: true)
        }
    }

    private func referenceDate() -> Date {
        calendar.date(from: DateComponents(year: 2024, month: 1, day: 15, hour: 8)) ?? Date()
    }
}

import XCTest
@testable import Move

final class ExerciseSelectionTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testRotationDistributesEvenly() {
        let exercises = (0..<4).map { index in
            Exercise(name: "Exercise \(index)",
                     emoji: "🏃",
                     category: "Mobility",
                     durationMinutes: 2,
                     difficulty: 1,
                     instructions: nil,
                     isActive: true)
        }
        let settings = ScheduleSettings(useFixedTimes: true,
                                        fixedTimes: [components(hour: 9), components(hour: 10), components(hour: 11), components(hour: 12)],
                                        useRandomWindows: false,
                                        randomStartHour: 9,
                                        randomEndHour: 12,
                                        maxRemindersPerDay: 4,
                                        minSpacingMinutes: 30,
                                        quietStartHour: 21,
                                        quietEndHour: 6,
                                        skipWeekends: false)
        let planner = SchedulingService.Planner(settings: settings,
                                                exercises: exercises,
                                                completions: [],
                                                calendar: calendar,
                                                now: referenceDate())
        let plan = planner.generatePlan(days: 1)
        let uniqueExercises = Set(plan.map { $0.exercise.id })
        XCTAssertEqual(uniqueExercises.count, exercises.count, "Each exercise should be used before repeating when possible")
    }

    func testQuietHoursExcluded() {
        let settings = ScheduleSettings(useFixedTimes: true,
                                        fixedTimes: [components(hour: 22)],
                                        useRandomWindows: false,
                                        randomStartHour: 21,
                                        randomEndHour: 23,
                                        maxRemindersPerDay: 2,
                                        minSpacingMinutes: 60,
                                        quietStartHour: 21,
                                        quietEndHour: 7,
                                        skipWeekends: false)
        let exercises = [Exercise(name: "Stretch",
                                  emoji: "🧘",
                                  category: "Mobility",
                                  durationMinutes: 5,
                                  difficulty: 1,
                                  instructions: nil,
                                  isActive: true)]
        let planner = SchedulingService.Planner(settings: settings,
                                                exercises: exercises,
                                                completions: [],
                                                calendar: calendar,
                                                now: referenceDate())
        let plan = planner.generatePlan(days: 1)
        XCTAssertTrue(plan.isEmpty, "Reminders inside quiet hours should be skipped")
    }

    private func referenceDate() -> Date {
        calendar.date(from: DateComponents(year: 2024, month: 3, day: 1, hour: 8)) ?? Date()
    }

    private func components(hour: Int, minute: Int = 0) -> DateComponents {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return components
    }
}

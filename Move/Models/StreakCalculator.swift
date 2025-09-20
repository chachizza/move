import Foundation

struct StreakCalculator {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func streakCount(from completions: [Completion]) -> Int {
        let groupedByDay = Dictionary(grouping: completions) { completion in
            calendar.startOfDay(for: completion.timestamp)
        }
        var streak = 0
        var cursor = calendar.startOfDay(for: Date())

        while groupedByDay[cursor] != nil {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}

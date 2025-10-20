import Foundation
import SwiftData
import UserNotifications

/// Encapsulates reminder planning and scheduling logic (7-day rolling horizon).
/// https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/1649518-add
actor SchedulingService {
    struct PlannedReminder: Identifiable, Equatable {
        let id: String
        let exercise: Exercise
        let fireDate: Date
        let displayText: String
    }

    struct ReminderSummary: Identifiable, Equatable {
        let id: String
        let exerciseID: UUID
        let exerciseName: String
        let emoji: String
        let fireDate: Date
    }

    private let container: ModelContainer
    private let notificationService: NotificationService
    private let calendar: Calendar
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init(container: ModelContainer, notificationService: NotificationService, calendar: Calendar = .current) {
        self.container = container
        self.notificationService = notificationService
        self.calendar = calendar
    }

    func refreshSchedule() async throws {
        let context = ModelContext(container)
        context.autosaveEnabled = true

        let settings = try fetchSettings(context: context)
        let exercises = try fetchExercises(context: context)

        guard !exercises.isEmpty else {
            await notificationService.replacePendingRequests(with: [])
            return
        }

        let completions = try fetchCompletions(context: context)
        let planner = Planner(settings: settings,
                              exercises: exercises,
                              completions: completions,
                              calendar: calendar,
                              now: Date())
        let plan = planner.generatePlan()
        if plan.isEmpty {
            print("[SchedulingService] Generated 0 reminders. Check schedule configuration or active exercises.")
        } else {
            let sample = plan.prefix(3).map { "\($0.exercise.name) @ \($0.fireDate.formatted(date: .abbreviated, time: .shortened))" }
            print("[SchedulingService] Generated \(plan.count) reminders. Next up: \(sample.joined(separator: ", ")).")
        }
        let requests = plan.prefix(64).map { reminder in
            buildRequest(for: reminder)
        }
        await notificationService.replacePendingRequests(with: requests)
    }

    func scheduleTestReminder() async throws {
        let context = ModelContext(container)
        let exercises = try fetchExercises(context: context)
        guard let exercise = exercises.first else { return }

        let content = UNMutableNotificationContent()
        content.title = exercise.name
        content.body = "Try \(exercise.name)."
        content.sound = .default
        content.categoryIdentifier = "MOVE_REMINDER"
        content.userInfo = [
            NotificationPayloadKey.exerciseID: exercise.id.uuidString,
            NotificationPayloadKey.scheduledDate: isoFormatter.string(from: Date().addingTimeInterval(60)),
            NotificationPayloadKey.requestID: "test-\(UUID().uuidString)",
            NotificationPayloadKey.exerciseEmoji: exercise.emoji
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        let request = UNNotificationRequest(identifier: "test-\(UUID().uuidString)",
                                            content: content,
                                            trigger: trigger)
        await notificationService.add(request: request)
    }

    func upcomingReminderSummaries() async -> [ReminderSummary] {
        let requests = await notificationService.pendingRequests()
        let summaries = requests.compactMap { request -> ReminderSummary? in
            guard let fireDate = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate(),
                  let exerciseIDString = request.content.userInfo[NotificationPayloadKey.exerciseID] as? String,
                  let exerciseID = UUID(uuidString: exerciseIDString) else {
                return nil
            }
            let name = request.content.title
            let rawEmoji = request.content.userInfo[NotificationPayloadKey.exerciseEmoji] as? String ?? ""
            let emoji: String
            if !rawEmoji.isEmpty {
                emoji = rawEmoji
            } else if let scalar = name.first {
                emoji = String(scalar)
            } else {
                emoji = "✨"
            }
            return ReminderSummary(id: request.identifier,
                                   exerciseID: exerciseID,
                                   exerciseName: name.isEmpty ? "Exercise" : name,
                                   emoji: emoji,
                                   fireDate: fireDate)
        }
        return summaries.sorted(by: { $0.fireDate < $1.fireDate })
    }

    func snoozeReminder(for exerciseID: UUID, from originalDate: Date) async {
        let newDate = originalDate.addingTimeInterval(15 * 60)
        await scheduleSingleReminder(exerciseID: exerciseID, fireDate: newDate, suffix: "snooze")
    }

    func swapExercise(at scheduledDate: Date, excluding exerciseID: UUID) async {
        let context = ModelContext(container)
        let exercises = try? fetchExercises(context: context)
        guard let exercises, !exercises.isEmpty else { return }
        let alternatives = exercises.filter { $0.id != exerciseID }
        guard let exercise = (alternatives.isEmpty ? exercises : alternatives).randomElement() else { return }
        await scheduleSingleReminder(exerciseID: exercise.id, fireDate: scheduledDate, suffix: "swap")
    }

    private func scheduleSingleReminder(exerciseID: UUID, fireDate: Date, suffix: String) async {
        let context = ModelContext(container)
        guard let exercise = try? context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == exerciseID })).first else {
            return
        }

        guard fireDate > Date() else { return }
        let reminder = PlannedReminder(id: "single-\(suffix)-\(UUID().uuidString)",
                                       exercise: exercise,
                                       fireDate: fireDate,
                                       displayText: exercise.name)
        await notificationService.add(request: buildRequest(for: reminder))
    }

    private func buildRequest(for reminder: PlannedReminder) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = reminder.exercise.name
        content.body = [reminder.displayText, "Tap Done when finished or Snooze for 15 minutes."].joined(separator: "\n\n")
        content.sound = .default
        content.categoryIdentifier = "MOVE_REMINDER"
        content.userInfo = [
            NotificationPayloadKey.exerciseID: reminder.exercise.id.uuidString,
            NotificationPayloadKey.scheduledDate: isoFormatter.string(from: reminder.fireDate),
            NotificationPayloadKey.requestID: reminder.id,
            NotificationPayloadKey.exerciseEmoji: reminder.exercise.emoji
        ]

        let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        return UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)
    }

    private func fetchSettings(context: ModelContext) throws -> ScheduleSettings {
        var descriptor = FetchDescriptor<ScheduleSettings>()
        descriptor.fetchLimit = 1
        if let settings = try context.fetch(descriptor).first {
            return settings
        }
        let settings = ScheduleSettings()
        context.insert(settings)
        return settings
    }

    private func fetchExercises(context: ModelContext) throws -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.isActive })
        return try context.fetch(descriptor)
    }

    private func fetchCompletions(context: ModelContext) throws -> [Completion] {
        var descriptor = FetchDescriptor<Completion>(sortBy: [SortDescriptor(\Completion.timestamp, order: .reverse)])
        descriptor.fetchLimit = 500
        return try context.fetch(descriptor)
    }
}

extension SchedulingService {
    struct Planner {
        let settings: ScheduleSettings
        let exercises: [Exercise]
        let completions: [Completion]
        let calendar: Calendar
        let now: Date
        private let identifierFormatter: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()

        func generatePlan(days: Int = 7) -> [PlannedReminder] {
            guard !exercises.isEmpty else { return [] }
            var results: [PlannedReminder] = []
            var rotation = ExerciseRotation(exercises: exercises, completions: completions)
            let startOfToday = calendar.startOfDay(for: now)
            let maxPerDay = max(settings.maxRemindersPerDay, 1)

            for dayOffset in 0..<days {
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
                if settings.skipWeekends, calendar.isDateInWeekend(day) { continue }

                var slots: [PlannedSlot] = settings.useFixedTimes ? fixedSlots(for: day) : []
                slots = slots.filter { isValid(time: $0.date) }

                if settings.useRandomWindows {
                    let additional = randomSlots(for: day, existing: slots, maxCount: maxPerDay)
                    slots.append(contentsOf: additional)
                }

                slots = sanitize(slots: slots, maxPerDay: maxPerDay)

                for slot in slots {
                    guard slot.date > now else { continue }
                    let exercise: Exercise
                    if let override = slot.exercise {
                        exercise = rotation.useSpecific(override)
                    } else {
                        exercise = rotation.next()
                    }
                    let reminder = PlannedReminder(id: "\(exercise.id.uuidString)-\(identifierFormatter.string(from: slot.date))",
                                                   exercise: exercise,
                                                   fireDate: slot.date,
                                                   displayText: reminderBody(for: exercise))
                    results.append(reminder)
                }
            }
            return results.sorted(by: { $0.fireDate < $1.fireDate })
        }

        private func reminderBody(for exercise: Exercise) -> String {
            if let instructions = exercise.instructions, !instructions.isEmpty {
                return instructions
            }
            return "You scheduled \(exercise.name)."
        }

        private func date(for slot: ScheduleSlot, on day: Date) -> Date? {
            var components = slot.asDateComponents()
            components.year = calendar.component(.year, from: day)
            components.month = calendar.component(.month, from: day)
            components.day = calendar.component(.day, from: day)
            if components.hour == nil {
                components.hour = 9
            }
            if components.minute == nil {
                components.minute = 0
            }
            return calendar.date(from: components)
        }

        private func fixedSlots(for day: Date) -> [PlannedSlot] {
            settings.fixedSlots.compactMap { slot in
                guard let date = date(for: slot, on: day) else { return nil }
                let exercise = slot.exerciseID.flatMap { id in
                    exercises.first(where: { $0.id == id })
                }
                return PlannedSlot(date: date, exercise: exercise)
            }
        }

        private func randomSlots(for day: Date, existing: [PlannedSlot], maxCount: Int) -> [PlannedSlot] {
            let remaining = max(0, maxCount - existing.count)
            guard remaining > 0 else { return [] }
            let startHour = settings.randomStartHour
            let endHour = settings.randomEndHour
            guard endHour > startHour else {
                // Assumption: random windows require endHour > startHour; otherwise no random slots generated.
                return []
            }

            var generated: [PlannedSlot] = []
            let attemptsCeiling = remaining * 20
            var attempts = 0
            while generated.count < remaining && attempts < attemptsCeiling {
                attempts += 1
                let randomHour = Int.random(in: startHour..<endHour)
                let randomMinute = Int.random(in: 0..<60)
                guard let candidate = calendar.date(bySettingHour: randomHour, minute: randomMinute, second: 0, of: day) else {
                    continue
                }
                if !isValid(time: candidate) { continue }
                var proposed = existing.map(\.date)
                proposed.append(contentsOf: generated.map(\.date))
                proposed.append(candidate)
                if satisfiesSpacing(times: proposed) {
                    generated.append(PlannedSlot(date: candidate, exercise: nil))
                }
            }
            return generated
        }

        private func sanitize(slots: [PlannedSlot], maxPerDay: Int) -> [PlannedSlot] {
            let ordered = slots.sorted(by: { $0.date < $1.date })
            var filtered: [PlannedSlot] = []
            for slot in ordered {
                if filtered.contains(where: { abs($0.date.timeIntervalSince(slot.date)) < 1 }) {
                    continue
                }
                if filtered.isEmpty || slot.date.timeIntervalSince(filtered.last!.date) >= Double(settings.minSpacingMinutes * 60) {
                    filtered.append(slot)
                }
            }
            return Array(filtered.prefix(maxPerDay))
        }

        private func satisfiesSpacing(times: [Date]) -> Bool {
            let sorted = times.sorted()
            for index in 1..<sorted.count {
                if sorted[index].timeIntervalSince(sorted[index - 1]) < Double(settings.minSpacingMinutes * 60) {
                    return false
                }
            }
            return true
        }

        private func isValid(time: Date) -> Bool {
            guard let hour = calendar.dateComponents([.hour], from: time).hour else { return false }
            if inQuietHours(hour: hour) { return false }
            return true
        }

        private func inQuietHours(hour: Int) -> Bool {
            let quietStart = settings.quietStartHour
            let quietEnd = settings.quietEndHour
            if quietStart == quietEnd { return false }
            if quietStart < quietEnd {
                return (quietStart..<quietEnd).contains(hour)
            } else {
                // Quiet hours wrapping past midnight.
                return hour >= quietStart || hour < quietEnd
            }
        }
    }

        struct PlannedSlot {
            let date: Date
            let exercise: Exercise?
        }

    struct ExerciseRotation {
        private var queue: [Exercise]
        private let ordered: [Exercise]

        init(exercises: [Exercise], completions: [Completion]) {
            let lastCompletion: [UUID: Date] = completions.reduce(into: [:]) { dict, completion in
                if dict[completion.exerciseID] == nil {
                    dict[completion.exerciseID] = completion.timestamp
                }
            }
            ordered = exercises.sorted { lhs, rhs in
                let lhsDate = lastCompletion[lhs.id] ?? .distantPast
                let rhsDate = lastCompletion[rhs.id] ?? .distantPast
                if lhsDate == rhsDate {
                    return lhs.name < rhs.name
                }
                return lhsDate < rhsDate
            }
            queue = ordered
        }

        mutating func next() -> Exercise {
            if queue.isEmpty {
                queue = ordered
            }
            guard !queue.isEmpty else {
                return ordered.first!
            }
            return queue.removeFirst()
        }

        mutating func useSpecific(_ exercise: Exercise) -> Exercise {
            if queue.isEmpty {
                queue = ordered
            }
            if let matchIndex = queue.firstIndex(where: { $0.id == exercise.id }) {
                queue.remove(at: matchIndex)
            }
            return exercise
        }
    }
}

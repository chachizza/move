import SwiftData
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var upcomingReminders: [SchedulingService.ReminderSummary] = []
    private weak var app: AppStartup?
    private var didConfigure = false
    private var reminderTask: Task<Void, Never>?

    deinit {
        reminderTask?.cancel()
    }

    func configureIfNeeded(app: AppStartup) {
        guard !didConfigure else { return }
        self.app = app
        didConfigure = true
        refreshUpcoming()
    }

    func refreshUpcoming() {
        reminderTask?.cancel()
        guard let app else { return }
        reminderTask = Task { [weak self] in
            let summaries = await app.schedulingService.upcomingReminderSummaries()
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                self.upcomingReminders = summaries
            }
        }
    }

    func suggestedExercise(from exercises: [Exercise], completions: [Completion]) -> Exercise? {
        let active = exercises.filter { $0.isActive }
        guard !active.isEmpty else { return nil }
        if let upcoming = upcomingReminders.first,
           let match = active.first(where: { $0.id == upcoming.exerciseID }) {
            return match
        }
        var rotation = SchedulingService.ExerciseRotation(exercises: active, completions: completions)
        return rotation.next()
    }

    func rotationOrder(exercises: [Exercise], completions: [Completion]) -> [Exercise] {
        let active = exercises.filter { $0.isActive }
        guard !active.isEmpty else { return [] }
        
        var rotation = SchedulingService.ExerciseRotation(exercises: active, completions: completions)
        var ordered: [Exercise] = []
        while ordered.count < active.count {
            let next = rotation.next()
            if !ordered.contains(where: { $0.id == next.id }) {
                ordered.append(next)
            }
        }
        return ordered
    }

    func completeNow(exercise: Exercise, context: ModelContext) {
        let completion = Completion(exerciseID: exercise.id)
        context.insert(completion)
        do {
            try context.save()
        } catch {
            print("Failed to save quick completion: \(error)")
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let service = self.app?.schedulingService {
                do {
                    try await service.refreshSchedule()
                } catch {
                    print("Refresh schedule failed after quick completion: \(error)")
                }
            }
            self.refreshUpcoming()
        }
    }
}

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

    func suggestedExercise(from exercises: [Exercise]) -> Exercise? {
        guard !exercises.isEmpty else { return nil }
        let active = exercises.filter { $0.isActive }
        if let upcoming = upcomingReminders.first,
           let match = active.first(where: { $0.name == upcoming.exerciseName }) {
            return match
        }
        return active.randomElement()
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

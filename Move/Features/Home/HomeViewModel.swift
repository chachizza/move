import SwiftData
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var upcomingReminders: [SchedulingService.ReminderSummary] = []
    private weak var app: AppStartup?
    private var didConfigure = false

    func configureIfNeeded(app: AppStartup) async {
        guard !didConfigure else { return }
        self.app = app
        didConfigure = true
        await refreshUpcoming()
    }

    func refreshUpcoming() async {
        guard let app else { return }
        upcomingReminders = await app.schedulingService.upcomingReminderSummaries()
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
            await self.refreshUpcoming()
        }
    }
}

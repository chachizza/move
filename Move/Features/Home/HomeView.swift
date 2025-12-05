import SwiftData
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var app: AppStartup
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \Completion.timestamp, order: .reverse) private var completions: [Completion]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        TabView {
            NavigationStack {
                HomeDashboardView(viewModel: viewModel,
                                   exercises: exercises,
                                   completions: completions)
                    .toolbar { refreshButton }
            }
            .tabItem { Label("Home", systemImage: "bolt.heart") }

            NavigationStack {
                ExercisesView()
            }
            .tabItem { Label("Exercises", systemImage: "figure.strengthtraining.traditional") }

            NavigationStack {
                ScheduleView()
            }
            .tabItem { Label("Schedule", systemImage: "calendar.badge.clock") }

            NavigationStack {
                HistoryView()
            }
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(MoveTheme.accent)
        .background(MoveTheme.canvas.ignoresSafeArea())
        .task {
            viewModel.configureIfNeeded(app: app)
        }
        .onChange(of: exercises.map(\.id)) { _, _ in
            viewModel.refreshUpcoming()
        }
        .onChange(of: completions.map(\.id)) { _, _ in
            viewModel.refreshUpcoming()
        }
    }

    private var refreshButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                viewModel.refreshUpcoming()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("Refresh reminders")
        }
    }
}

private struct HomeDashboardView: View {
    @ObservedObject var viewModel: HomeViewModel
    let exercises: [Exercise]
    let completions: [Completion]
    @EnvironmentObject private var app: AppStartup
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                nextReminderCard
                streakCard
                rotationCard
                quickActionCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .background(MoveTheme.canvas.ignoresSafeArea())
    }

    private var nextReminderCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Next Reminder")
                    .font(.headline)
                if let next = viewModel.upcomingReminders.sorted(by: { $0.fireDate < $1.fireDate }).first {
                    Text("\(next.emoji) \(next.exerciseName)")
                        .font(.system(size: 24, weight: .bold, design: .default))
                        .minimumScaleFactor(0.6)
                    Text(next.fireDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(MoveTheme.muted)
                } else {
                    EmptyStateView(emoji: "🗓",
                                   title: "No Reminder",
                                   message: "Schedule settings determine what appears here.")
                }
            }
        }
    }

    private var streakCard: some View {
        CardView {
            let streak = app.streakCalculator.streakCount(from: completions)
            VStack(alignment: .leading, spacing: 12) {
                Text("Current Streak")
                    .font(.headline)
                Text("\(streak) Day\(streak == 1 ? "" : "s")")
                    .font(.system(size: 48, weight: .black, design: .default))
                    .foregroundStyle(MoveTheme.primary)
                Text(streak == 0 ? "Start building your momentum." : "Keep the momentum going today.")
                    .font(.footnote)
                    .foregroundStyle(MoveTheme.muted)
            }
        }
    }

    private var rotationCard: some View {
        CardView {
            let active = exercises.filter { $0.isActive }
            VStack(alignment: .leading, spacing: 12) {
                Text("Rotation Order")
                    .font(.headline)
                if active.isEmpty {
                    Text("Activate exercises to build your routine.")
                        .font(.subheadline)
                        .foregroundStyle(MoveTheme.muted)
                } else {
                    let ordered = viewModel.rotationOrder(exercises: exercises, completions: completions)
                    ForEach(Array(ordered.enumerated()), id: \.offset) { index, exercise in
                        HStack(spacing: 16) {
                            Text(String(format: "%02d", index + 1))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(MoveTheme.primary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(exercise.emoji) \(exercise.name)")
                                    .font(.subheadline.weight(.heavy))
                                if let instructions = exercise.instructions, !instructions.isEmpty {
                                    Text(instructions)
                                        .font(.caption)
                                        .foregroundStyle(MoveTheme.muted)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var quickActionCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Action")
                    .font(.headline)
                if let exercise = viewModel.suggestedExercise(from: exercises, completions: completions) {
                    Button {
                        viewModel.completeNow(exercise: exercise, context: modelContext)
                    } label: {
                        Label("Log \(exercise.name)", systemImage: "checkmark.circle")
                            .font(.headline)
                    }
                    .buttonStyle(.primary)
                } else {
                    Text("Add an exercise to enable quick logging.")
                        .font(.subheadline)
                        .foregroundStyle(MoveTheme.muted)
                }
                
                if !exercises.isEmpty {
                    Menu {
                        ForEach(exercises.filter { $0.isActive }.sorted(by: { $0.name < $1.name })) { exercise in
                            Button {
                                viewModel.completeNow(exercise: exercise, context: modelContext)
                            } label: {
                                Label(exercise.name, systemImage: "checkmark")
                            }
                        }
                    } label: {
                        Label("Log Other...", systemImage: "list.bullet")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(MoveTheme.background)
                            .foregroundStyle(MoveTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(MoveTheme.muted.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    private func rotationOrder(for active: [Exercise]) -> [Exercise] {
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

}

#Preview {
    HomeView()
        .environmentObject(PreviewStartup.shared.app)
        .modelContainer(PreviewStartup.shared.app.container)
}

@MainActor
private enum PreviewStartup {
    static let shared: Helper = {
        let helper = Helper()
        helper.bootstrap()
        return helper
    }()

    @MainActor
    final class Helper {
        let app = AppStartup()

        func bootstrap() {
            Task { @MainActor in
                await app.configureIfNeeded()
            }
        }
    }
}

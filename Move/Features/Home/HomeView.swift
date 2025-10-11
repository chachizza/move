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
                    .navigationTitle("MOVE")
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
        .tint(MoveTheme.primary)
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
                Text("NEXT REMINDER")
                    .font(.headline)
                    .tracking(1.2)
                if let next = viewModel.upcomingReminders.sorted(by: { $0.fireDate < $1.fireDate }).first {
                    Text("\(next.emoji) \(next.exerciseName.uppercased())")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.6)
                    Text(next.fireDate.formatted(date: .abbreviated, time: .shortened).uppercased())
                        .font(.subheadline)
                        .foregroundStyle(MoveTheme.muted)
                } else {
                    EmptyStateView(emoji: "🗓",
                                   title: "No reminder",
                                   message: "Schedule settings determine what appears here.")
                }
            }
        }
    }

    private var streakCard: some View {
        CardView {
            let streak = app.streakCalculator.streakCount(from: completions)
            VStack(alignment: .leading, spacing: 12) {
                Text("CURRENT STREAK")
                    .font(.headline)
                    .tracking(1.2)
                Text("\(streak) DAY\(streak == 1 ? "" : "S")")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(MoveTheme.primary)
                Text(streak == 0 ? "START BUILDING YOUR MOMENTUM." : "KEEP THE MOMENTUM GOING TODAY.")
                    .font(.footnote)
                    .foregroundStyle(MoveTheme.muted)
            }
        }
    }

    private var rotationCard: some View {
        CardView {
            let active = exercises.filter { $0.isActive }
            VStack(alignment: .leading, spacing: 12) {
                Text("ROTATION ORDER")
                    .font(.headline)
                    .tracking(1.2)
                if active.isEmpty {
                    Text("ACTIVATE EXERCISES TO BUILD YOUR ROUTINE.")
                        .font(.subheadline)
                        .foregroundStyle(MoveTheme.muted)
                } else {
                    let ordered = rotationOrder(for: active)
                    ForEach(Array(ordered.enumerated()), id: \.offset) { index, exercise in
                        HStack(spacing: 16) {
                            Text(String(format: "%02d", index + 1))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(MoveTheme.primary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(exercise.emoji) \(exercise.name.uppercased())")
                                    .font(.subheadline.weight(.heavy))
                                if let instructions = exercise.instructions, !instructions.isEmpty {
                                    Text(instructions.uppercased())
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
                Text("QUICK ACTION")
                    .font(.headline)
                    .tracking(1.2)
                if let exercise = viewModel.suggestedExercise(from: exercises, completions: completions) {
                    Button {
                        viewModel.completeNow(exercise: exercise, context: modelContext)
                    } label: {
                        Label("LOG \(exercise.name.uppercased())", systemImage: "checkmark.circle")
                            .font(.headline)
                    }
                    .buttonStyle(.primary)
                } else {
                    Text("ADD AN EXERCISE TO ENABLE QUICK LOGGING.")
                        .font(.subheadline)
                        .foregroundStyle(MoveTheme.muted)
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

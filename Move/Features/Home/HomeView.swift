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
                    .navigationTitle("Move")
                    .toolbar { refreshButton }
                    .background(Color("MoveBackground").ignoresSafeArea())
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
        .task {
            await viewModel.configureIfNeeded(app: app)
        }
        .onChange(of: exercises.map(\.id)) { _ in
            Task { await viewModel.refreshUpcoming() }
        }
        .onChange(of: completions.map(\.id)) { _ in
            Task { await viewModel.refreshUpcoming() }
        }
    }

    private var refreshButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                Task { await viewModel.refreshUpcoming() }
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
            VStack(spacing: 24) {
                streakCard
                upcomingCard
                quickActions
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 32)
        }
    }

    private var streakCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Current Streak")
                    .font(.headline)
                    .foregroundStyle(MoveTheme.text)
                Text("\(app.streakCalculator.streakCount(from: completions)) days")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(MoveTheme.primary)
                Text("Keep it going by completing at least one reminder each day.")
                    .font(.footnote)
                    .foregroundStyle(MoveTheme.muted)
            }
        }
    }

    private var upcomingCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Next Reminders")
                    .font(.headline)
                if viewModel.upcomingReminders.isEmpty {
                    EmptyStateView(emoji: "✨",
                                   title: "All clear",
                                   message: "No reminders are scheduled. Adjust your schedule or add exercises to get started.")
                } else {
                    ForEach(viewModel.upcomingReminders.prefix(3)) { reminder in
                        HStack(spacing: 16) {
                            Text(reminder.emoji)
                                .font(.system(size: 36))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reminder.exerciseName)
                                    .font(.headline)
                                Text(reminder.fireDate.formatted(date: .omitted, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundStyle(MoveTheme.muted)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        if reminder.id != viewModel.upcomingReminders.prefix(3).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let exercise = viewModel.suggestedExercise(from: exercises) {
                Button {
                    viewModel.completeNow(exercise: exercise, context: modelContext)
                } label: {
                    Label("Do \(exercise.name) now", systemImage: "play.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.primary)
            } else {
                EmptyStateView(emoji: "🛠",
                               title: "No active exercises",
                               message: "Activate or add exercises to unlock quick actions.")
            }
        }
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

import SwiftData
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var app: AppStartup
    @Query(sort: \Completion.timestamp, order: .reverse) private var completions: [Completion]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    private var exerciseLookup: [UUID: Exercise] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryCard
                if completions.isEmpty {
                    EmptyStateView(emoji: "🎯",
                                   title: "No History Yet",
                                   message: "Complete reminders or log quick actions to build your streak.")
                } else {
                    ForEach(sortedDays, id: \.self) { day in
                        dayCard(for: day, entries: groupedCompletions[day] ?? [])
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .background(MoveTheme.canvas.ignoresSafeArea())
        .navigationTitle("History")
        .tint(MoveTheme.primary)
    }

    private var groupedCompletions: [Date: [Completion]] {
        Dictionary(grouping: completions) { completion in
            Calendar.current.startOfDay(for: completion.timestamp)
        }
    }

    private var sortedDays: [Date] {
        groupedCompletions.keys.sorted(by: >)
    }

    private var summaryCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Summary")
                    .font(.headline)
                Label("Current streak: \(app.streakCalculator.streakCount(from: completions)) days", systemImage: "flame")
                    .font(.subheadline.weight(.bold))
                Label("Total completions: \(completions.count)", systemImage: "checkmark.circle")
                    .font(.subheadline.weight(.bold))
            }
        }
    }

    private func dayCard(for day: Date, entries: [Completion]) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text(day.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                ForEach(entries, id: \.id) { completion in
                    HStack(alignment: .center, spacing: 12) {
                        if let exercise = exerciseLookup[completion.exerciseID] {
                            Text(exercise.emoji)
                                .font(.title3)
                            Text(exercise.name)
                                .font(.subheadline.weight(.heavy))
                        } else {
                            Text("🏃")
                                .font(.title3)
                            Text("Exercise")
                                .font(.subheadline.weight(.heavy))
                        }
                        Spacer()
                        Text(completion.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MoveTheme.muted)
                    }
                    if completion.id != entries.last?.id {
                        Divider()
                            .overlay(MoveTheme.canvas)
                    }
                }
            }
        }
    }
}

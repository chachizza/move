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
        List {
            Section("SUMMARY") {
                Label("CURRENT STREAK: \(app.streakCalculator.streakCount(from: completions)) DAYS", systemImage: "flame")
                Label("TOTAL COMPLETIONS: \(completions.count)", systemImage: "checkmark.circle")
            }

            let grouped = Dictionary(grouping: completions) { completion in
                Calendar.current.startOfDay(for: completion.timestamp)
            }
            let sortedKeys = grouped.keys.sorted(by: >)
            ForEach(sortedKeys, id: \.self) { day in
                Section(day.formatted(date: .abbreviated, time: .omitted).uppercased()) {
                    ForEach(grouped[day] ?? [], id: \.id) { completion in
                        HStack {
                            if let exercise = exerciseLookup[completion.exerciseID] {
                                Text(exercise.emoji)
                                Text(exercise.name)
                            } else {
                                Text("🏃")
                                Text("Exercise")
                            }
                            Spacer()
                            Text(completion.timestamp.formatted(date: .omitted, time: .shortened))
                                .foregroundStyle(MoveTheme.muted)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listRowBackground(MoveTheme.background)
        .scrollContentBackground(.hidden)
        .background(MoveTheme.canvas.ignoresSafeArea())
        .navigationTitle("HISTORY")
        .tint(MoveTheme.primary)
    }
}

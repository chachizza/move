import SwiftData
import SwiftUI

struct ExercisesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var selectedExercise: Exercise?
    @State private var isPresentingEditor = false

    var body: some View {
        List {
            if exercises.isEmpty {
                Section {
                    EmptyStateView(emoji: "🧘",
                                   title: "No exercises yet",
                                   message: "Add exercises with emojis, instructions, and durations to personalize reminders.")
                        .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(exercises) { exercise in
                    Button {
                        selectedExercise = exercise
                        isPresentingEditor = true
                    } label: {
                        ExerciseRow(exercise: exercise)
                    }
                    .swipeActions(allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            modelContext.delete(exercise)
                            do {
                                try modelContext.save()
                            } catch {
                                print("Failed to delete exercise: \(error)")
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            exercise.isActive.toggle()
                            do {
                                try modelContext.save()
                            } catch {
                                print("Failed to toggle exercise: \(error)")
                            }
                        } label: {
                            Label(exercise.isActive ? "Disable" : "Enable", systemImage: exercise.isActive ? "pause.circle" : "play.circle")
                        }
                        .tint(exercise.isActive ? .orange : MoveTheme.primary)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("MoveBackground"))
        .navigationTitle("Exercises")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    selectedExercise = nil
                    isPresentingEditor = true
                } label: {
                    Label("Add exercise", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            NavigationStack {
                EditExerciseView(exercise: selectedExercise)
            }
        }
    }
}

private struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 16) {
            Text(exercise.emoji)
                .font(.system(size: 40))
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.headline)
                Text("\(exercise.durationMinutes) min • Difficulty \(exercise.difficulty)")
                    .font(.caption)
                    .foregroundStyle(MoveTheme.muted)
            }
            Spacer()
            if !exercise.isActive {
                Text("Inactive")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exercise.name), \(exercise.durationMinutes) minutes, difficulty \(exercise.difficulty)")
    }
}

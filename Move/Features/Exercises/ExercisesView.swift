import SwiftData
import SwiftUI

struct ExercisesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var selectedExercise: Exercise?
    @State private var isPresentingEditor = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if exercises.isEmpty {
                    EmptyStateView(emoji: "🧘",
                                   title: "No Exercises Yet",
                                   message: "Add exercises with emojis, instructions, and durations to personalize reminders.")
                        .frame(maxWidth: .infinity)
                } else {
                    exerciseSection(title: "Active Exercises", items: exercises.filter { $0.isActive })
                    exerciseSection(title: "Inactive Exercises", items: exercises.filter { !$0.isActive })
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .background(MoveTheme.canvas.ignoresSafeArea())
        .navigationTitle("Exercises")
        .tint(MoveTheme.primary)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    selectedExercise = nil
                    isPresentingEditor = true
                } label: {
                    Label("Add Exercise", systemImage: "plus")
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
        EmptyView()
    }
}

private extension ExercisesView {
    func exerciseSection(title: String, items: [Exercise]) -> some View {
        Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                        .font(.headline)
                    ForEach(items) { exercise in
                        ExerciseCard(exercise: exercise,
                                     onEdit: { selectedExercise = exercise; isPresentingEditor = true },
                                     onToggle: { toggle(exercise: exercise) },
                                     onDelete: { delete(exercise: exercise) })
                    }
                }
            }
        }
    }

    func toggle(exercise: Exercise) {
        exercise.isActive.toggle()
        do {
            try modelContext.save()
        } catch {
            print("Failed to toggle exercise: \(error)")
        }
    }

    func delete(exercise: Exercise) {
        modelContext.delete(exercise)
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete exercise: \(error)")
        }
    }
}

private struct ExerciseCard: View {
    let exercise: Exercise
    let onEdit: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    Text(exercise.emoji)
                        .font(.system(size: 44))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(.title3.weight(.heavy))
                        Text("\(exercise.durationMinutes) min • Difficulty \(exercise.difficulty)")
                            .font(.caption)
                            .foregroundStyle(MoveTheme.muted)
                    }
                    Spacer()
                    Text(exercise.isActive ? "Active" : "Inactive")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(exercise.isActive ? MoveTheme.primary : Color.orange)
                }

                if let instructions = exercise.instructions, !instructions.isEmpty {
                    Text(instructions)
                        .font(.caption)
                        .foregroundStyle(MoveTheme.muted)
                }

                VStack(spacing: 12) {
                    Button("Edit Exercise", action: onEdit)
                        .buttonStyle(.primary)
                    HStack(spacing: 12) {
                        Button(exercise.isActive ? "Disable" : "Enable") {
                            onToggle()
                        }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(MoveTheme.accent)
                            .foregroundStyle(MoveTheme.text)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Text("Delete")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .background(MoveTheme.primary)
                        .foregroundColor(MoveTheme.text)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }
            }
        }
    }
}

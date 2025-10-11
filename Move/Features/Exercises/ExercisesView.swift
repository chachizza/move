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
                                   title: "No exercises yet",
                                   message: "Add exercises with emojis, instructions, and durations to personalize reminders.")
                        .frame(maxWidth: .infinity)
                } else {
                    exerciseSection(title: "ACTIVE EXERCISES", items: exercises.filter { $0.isActive })
                    exerciseSection(title: "INACTIVE EXERCISES", items: exercises.filter { !$0.isActive })
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .background(MoveTheme.canvas.ignoresSafeArea())
        .navigationTitle("EXERCISES")
        .tint(MoveTheme.primary)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    selectedExercise = nil
                    isPresentingEditor = true
                } label: {
                    Label("ADD EXERCISE", systemImage: "plus")
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
                        .tracking(1.2)
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
                        Text(exercise.name.uppercased())
                            .font(.title3.weight(.heavy))
                        Text("\(exercise.durationMinutes) MIN • DIFFICULTY \(exercise.difficulty)")
                            .font(.caption)
                            .foregroundStyle(MoveTheme.muted)
                    }
                    Spacer()
                    Text(exercise.isActive ? "ACTIVE" : "INACTIVE")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(exercise.isActive ? MoveTheme.primary : Color.orange)
                }

                if let instructions = exercise.instructions, !instructions.isEmpty {
                    Text(instructions.uppercased())
                        .font(.caption)
                        .foregroundStyle(MoveTheme.muted)
                }

                VStack(spacing: 12) {
                    Button("EDIT EXERCISE", action: onEdit)
                        .buttonStyle(.primary)
                    HStack(spacing: 12) {
                        Button((exercise.isActive ? "DISABLE" : "ENABLE")) {
                            onToggle()
                        }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(MoveTheme.accent)
                            .foregroundStyle(MoveTheme.background)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Text("DELETE")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .textCase(.uppercase)
                        }
                        .background(MoveTheme.primary)
                        .foregroundColor(MoveTheme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }
            }
        }
    }
}

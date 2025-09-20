import SwiftData
import SwiftUI

struct EditExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let exercise: Exercise?

    @State private var name: String
    @State private var emoji: String
    @State private var category: String
    @State private var durationMinutes: Int
    @State private var difficulty: Int
    @State private var instructions: String
    @State private var isActive: Bool

    @FocusState private var focusedField: Field?

    private enum Field {
        case name, emoji
    }

    init(exercise: Exercise?) {
        self.exercise = exercise
        _name = State(initialValue: exercise?.name ?? "")
        _emoji = State(initialValue: exercise?.emoji ?? "💪")
        _category = State(initialValue: exercise?.category ?? "General")
        _durationMinutes = State(initialValue: exercise?.durationMinutes ?? 2)
        _difficulty = State(initialValue: exercise?.difficulty ?? 1)
        _instructions = State(initialValue: exercise?.instructions ?? "")
        _isActive = State(initialValue: exercise?.isActive ?? true)
    }

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Emoji", text: $emoji)
                    .font(.system(size: 32))
                    .focused($focusedField, equals: .emoji)
                    .onChange(of: emoji) { _, newValue in
                        emoji = String(newValue.prefix(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                TextField("Name", text: $name)
                    .focused($focusedField, equals: .name)
                TextField("Category", text: $category)
            }

            Section("Details") {
                Stepper(value: $durationMinutes, in: 1...30, step: 1) {
                    Label("Duration: \(durationMinutes) min", systemImage: "timer")
                }
                Stepper(value: $difficulty, in: 1...5) {
                    Label("Difficulty: \(difficulty)", systemImage: "flame")
                }
                Toggle("Active", isOn: $isActive)
            }

            Section("Instructions") {
                TextEditor(text: $instructions)
                    .frame(minHeight: 120)
                    .overlay(alignment: .topLeading) {
                        if instructions.isEmpty {
                            Text("Optional cues or reminders")
                                .foregroundStyle(MoveTheme.muted)
                                .padding(.top, 8)
                        }
                    }
            }
        }
        .navigationTitle(exercise == nil ? "New Exercise" : "Edit Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if let exercise {
            exercise.name = trimmedName
            exercise.emoji = emoji
            exercise.category = category
            exercise.durationMinutes = durationMinutes
            exercise.difficulty = difficulty
            exercise.instructions = instructions.isEmpty ? nil : instructions
            exercise.isActive = isActive
        } else {
            let newExercise = Exercise(name: trimmedName,
                                       emoji: emoji,
                                       category: category,
                                       durationMinutes: durationMinutes,
                                       difficulty: difficulty,
                                       instructions: instructions.isEmpty ? nil : instructions,
                                       isActive: isActive)
            modelContext.insert(newExercise)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save exercise: \(error)")
        }
    }
}

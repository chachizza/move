import SwiftData
import SwiftUI

struct EditExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let exercise: Exercise?
    @StateObject private var viewModel: ViewModel
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, emoji
    }

    init(exercise: Exercise?) {
        self.exercise = exercise
        _viewModel = StateObject(wrappedValue: ViewModel(exercise: exercise))
    }

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Emoji", text: $viewModel.emoji)
                    .font(.system(size: 32))
                    .focused($focusedField, equals: .emoji)
                    .onChange(of: viewModel.emoji) { _, newValue in
                        viewModel.emoji = String(newValue.prefix(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                TextField("Name", text: $viewModel.name)
                    .focused($focusedField, equals: .name)
                TextField("Category", text: $viewModel.category)
            }

            Section("Details") {
                Stepper(value: $viewModel.durationMinutes, in: 1...30, step: 1) {
                    Label("Duration: \(viewModel.durationMinutes) min", systemImage: "timer")
                }
                Stepper(value: $viewModel.difficulty, in: 1...5) {
                    Label("Difficulty: \(viewModel.difficulty)", systemImage: "flame")
                }
                Toggle("Active", isOn: $viewModel.isActive)
            }

            Section("Instructions") {
                TextEditor(text: $viewModel.instructions)
                    .frame(minHeight: 120)
                    .overlay(alignment: .topLeading) {
                        if viewModel.instructions.isEmpty {
                            Text("Optional cues or reminders")
                                .foregroundStyle(MoveTheme.muted)
                                .padding(.top, 8)
                        }
                    }
            }
        }
        .listRowBackground(MoveTheme.background)
        .scrollContentBackground(.hidden)
        .background(MoveTheme.canvas.ignoresSafeArea())
        .navigationTitle(exercise == nil ? "New Exercise" : "Edit Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .tint(MoveTheme.primary)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let trimmedName = viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if let exercise {
            exercise.name = trimmedName
            exercise.emoji = viewModel.emoji
            exercise.category = viewModel.category
            exercise.durationMinutes = viewModel.durationMinutes
            exercise.difficulty = viewModel.difficulty
            exercise.instructions = viewModel.instructions.isEmpty ? nil : viewModel.instructions
            exercise.isActive = viewModel.isActive
        } else {
            let newExercise = Exercise(name: trimmedName,
                                       emoji: viewModel.emoji,
                                       category: viewModel.category,
                                       durationMinutes: viewModel.durationMinutes,
                                       difficulty: viewModel.difficulty,
                                       instructions: viewModel.instructions.isEmpty ? nil : viewModel.instructions,
                                       isActive: viewModel.isActive)
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

extension EditExerciseView {
    @MainActor
    final class ViewModel: ObservableObject {
        @Published var name: String
        @Published var emoji: String
        @Published var category: String
        @Published var durationMinutes: Int
        @Published var difficulty: Int
        @Published var instructions: String
        @Published var isActive: Bool

        init(exercise: Exercise?) {
            self.name = exercise?.name ?? ""
            self.emoji = exercise?.emoji ?? "💪"
            self.category = exercise?.category ?? "General"
            self.durationMinutes = exercise?.durationMinutes ?? 2
            self.difficulty = exercise?.difficulty ?? 1
            self.instructions = exercise?.instructions ?? ""
            self.isActive = exercise?.isActive ?? true
        }
    }
}

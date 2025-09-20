import SwiftUI

struct ExerciseDetailView: View {
    let exercise: Exercise

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 16) {
                    Text(exercise.emoji)
                        .font(.system(size: 80))
                    VStack(alignment: .leading, spacing: 8) {
                        Text(exercise.name)
                            .font(.largeTitle.bold())
                        Text(exercise.category)
                            .font(.headline)
                            .foregroundStyle(MoveTheme.muted)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Duration: \(exercise.durationMinutes) min", systemImage: "timer")
                    Label("Difficulty: \(exercise.difficulty)", systemImage: "flame")
                    Label(exercise.isActive ? "Active" : "Inactive", systemImage: exercise.isActive ? "checkmark.circle" : "pause.circle")
                        .foregroundStyle(exercise.isActive ? .green : .orange)
                }
                .font(.headline)

                if let instructions = exercise.instructions {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instructions")
                            .font(.headline)
                        Text(instructions)
                            .font(.body)
                    }
                }
                Spacer()
            }
            .padding()
        }
        .background(Color("MoveBackground").ignoresSafeArea())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

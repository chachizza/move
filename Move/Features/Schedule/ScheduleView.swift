import SwiftData
import SwiftUI

struct ScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var app: AppStartup
    @Query private var settings: [ScheduleSettings]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @StateObject private var viewModel = ScheduleViewModel()
    @State private var isSaving = false

    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                fixedTimesCard
                randomWindowsCard
                limitsCard
                actionsCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .background(MoveTheme.canvas.ignoresSafeArea())
        .navigationTitle("Schedule")
        .tint(MoveTheme.primary)
        .onAppear {
            viewModel.configure(with: settings.first)
        }
        .onChange(of: viewModel.randomStartHour) { _, newValue in
            if newValue >= viewModel.randomEndHour {
                viewModel.randomEndHour = min(newValue + 1, 23)
            }
        }
        .onChange(of: viewModel.randomEndHour) { _, newValue in
            if newValue <= viewModel.randomStartHour {
                viewModel.randomStartHour = max(newValue - 1, 0)
            }
        }
    }

    private var fixedTimesCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Fixed Times")
                    .font(.headline)
                    .tracking(1.2)
                Toggle("Use fixed reminder times", isOn: $viewModel.useFixedTimes)
                    .tint(MoveTheme.primary)

                if viewModel.useFixedTimes {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.fixedSlots.indices, id: \.self) { index in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    let slotLabel = String(format: "%02d", index + 1)
                                    Text("Slot \(slotLabel)")
                                        .font(.subheadline.weight(.heavy))
                                    Spacer()
                                    Button(role: .destructive) {
                                        viewModel.removeFixedTime(at: IndexSet(integer: index))
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                            .labelStyle(.titleAndIcon)
                                            .font(.caption.bold())
                                    }
                                }
                                DatePicker("Time", selection: timeBinding(for: index), displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                Picker("Exercise", selection: exerciseBinding(for: index)) {
                                    Text("Next in rotation").tag(nil as UUID?)
                                    ForEach(exercises.filter { $0.isActive }) { exercise in
                                        Text(exercise.name).tag(Optional(exercise.id))
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            if index != viewModel.fixedSlots.indices.last {
                                Divider()
                                    .overlay(MoveTheme.canvas)
                            }
                        }

                        Button {
                            viewModel.addFixedTime()
                        } label: {
                            Label("Add Another Time", systemImage: "plus")
                                .font(.headline)
                        }
                        .buttonStyle(.primary)
                    }
                }
            }
        }
    }

    private var randomWindowsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Random Windows")
                    .font(.headline)
                    .tracking(1.2)
                Toggle("Fill remaining slots with randomized windows", isOn: $viewModel.useRandomWindows)
                    .tint(MoveTheme.primary)
                if viewModel.useRandomWindows {
                    VStack(alignment: .leading, spacing: 12) {
                        Stepper(value: $viewModel.randomStartHour, in: 5...22) {
                            Label("Start hour: \(formattedHour(viewModel.randomStartHour))", systemImage: "sunrise")
                        }
                        Stepper(value: $viewModel.randomEndHour, in: 6...23) {
                            Label("End hour: \(formattedHour(viewModel.randomEndHour))", systemImage: "sunset")
                        }
                        Text("Randomized reminders respect quiet hours and spacing requirements.")
                            .font(.footnote)
                            .foregroundStyle(MoveTheme.muted)
                    }
                }
            }
        }
    }

    private var limitsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Limits & Quiet Hours")
                    .font(.headline)
                    .tracking(1.2)
                Stepper(value: $viewModel.maxRemindersPerDay, in: 1...10) {
                    Label("Max per day: \(viewModel.maxRemindersPerDay)", systemImage: "number")
                }
                Stepper(value: $viewModel.minSpacingMinutes, in: 15...240, step: 15) {
                    Label("Minimum spacing: \(viewModel.minSpacingMinutes) min", systemImage: "timer")
                }
                Stepper(value: $viewModel.quietStartHour, in: 0...23) {
                    Label("Quiet hours start: \(formattedHour(viewModel.quietStartHour))", systemImage: "moon.zzz")
                }
                Stepper(value: $viewModel.quietEndHour, in: 0...23) {
                    Label("Quiet hours end: \(formattedHour(viewModel.quietEndHour))", systemImage: "sun.max")
                }
                Toggle("Skip weekends", isOn: $viewModel.skipWeekends)
                    .tint(MoveTheme.primary)
            }
        }
    }

    private var actionsCard: some View {
        CardView {
            VStack(spacing: 12) {
                Button {
                    save()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Label("Save Schedule", systemImage: "checkmark")
                            .font(.headline)
                    }
                }
                .buttonStyle(.primary)
                .disabled(isSaving)

                Text("Saving regenerates the next seven days using the latest settings.")
                    .font(.footnote)
                    .foregroundStyle(MoveTheme.muted)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func timeBinding(for index: Int) -> Binding<Date> {
        Binding { () -> Date in
            guard index < viewModel.fixedSlots.count else { return Date() }
            let slot = viewModel.fixedSlots[index]
            let base = Date()
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: base)
            dateComponents.hour = slot.hour ?? 10
            dateComponents.minute = slot.minute ?? 0
            return calendar.date(from: dateComponents) ?? base
        } set: { newDate in
            viewModel.updateFixedTime(at: index, to: newDate, calendar: calendar)
        }
    }

    private func exerciseBinding(for index: Int) -> Binding<UUID?> {
        Binding {
            guard index < viewModel.fixedSlots.count else { return nil }
            return viewModel.fixedSlots[index].exerciseID
        } set: { newValue in
            viewModel.updateExercise(at: index, to: newValue)
        }
    }

    private func formattedHour(_ hour: Int) -> String {
        let clamped = max(0, min(hour, 23))
        var components = DateComponents()
        components.hour = clamped
        components.minute = 0
        return calendar.date(from: components)?.formatted(date: .omitted, time: .shortened) ?? "--"
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        Task { @MainActor in
            await viewModel.save(modelContext: modelContext, schedulingService: app.schedulingService)
            isSaving = false
        }
    }
}

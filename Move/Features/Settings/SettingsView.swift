import SwiftData
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppStartup
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingResetConfirmation = false
    @State private var alertMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                notificationsCard
                dangerCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .background(MoveTheme.canvas.ignoresSafeArea())
        .navigationTitle("Settings")
        .tint(MoveTheme.primary)
        .task {
            await viewModel.configure(app: app)
        }
        .alert("Reset Move?", isPresented: $showingResetConfirmation, actions: {
            Button("Cancel", role: .cancel, action: {})
            Button("Reset", role: .destructive) {
                Task { await viewModel.resetData(context: modelContext) }
            }
        }, message: {
            Text("This removes all exercises, schedules, and history, then restores the default seed data.")
        })
        .onChange(of: viewModel.alertMessage) { _, newValue in
            alertMessage = newValue
        }
        .alert(alertMessage ?? "", isPresented: Binding(get: { alertMessage != nil }, set: { newValue in
            if !newValue { alertMessage = nil }
        })) {
            Button("OK", role: .cancel) { alertMessage = nil }
        }
    }

    private var notificationsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Notifications")
                    .font(.headline)
                HStack {
                    Label(viewModel.notificationsAuthorized ? "Notifications enabled" : "Notifications disabled",
                          systemImage: viewModel.notificationsAuthorized ? "bell.badge" : "bell.slash")
                        .foregroundStyle(viewModel.notificationsAuthorized ? .green : .orange)
                    Spacer()
                }
                Label("Scheduled reminders: \(viewModel.pendingReminderCount)", systemImage: "calendar.badge.clock")
                    .foregroundStyle(MoveTheme.muted)
                VStack(spacing: 12) {
                    Button("Request Permission", action: requestNotifications)
                        .buttonStyle(.primary)
                    Button("Schedule Test Reminder", action: scheduleTestReminder)
                        .buttonStyle(.primary)
                    Button("Refresh Reminder Count") {
                        Task { await viewModel.refreshPendingReminderCount() }
                    }
                    .buttonStyle(.primary)
                    Button("Regenerate Next 7 Days") {
                        Task { await viewModel.regenerateSchedule() }
                    }
                    .buttonStyle(.primary)
                }
            }
        }
    }

    private var dangerCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Danger Zone")
                    .font(.headline)
                Button(role: .destructive) {
                    showingResetConfirmation = true
                } label: {
                    Label("Reset All Data", systemImage: "trash")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.red)
                .foregroundColor(MoveTheme.text)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
    }

    private func requestNotifications() {
        Task {
            await viewModel.requestNotifications()
        }
    }

    private func scheduleTestReminder() {
        Task {
            await viewModel.scheduleTestReminder()
        }
    }
}

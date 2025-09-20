import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var app: AppStartup
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingImporter = false
    @State private var showingResetConfirmation = false
    @State private var alertMessage: String?

    var body: some View {
        Form {
            Section("Notifications") {
                HStack {
                    Label(viewModel.notificationsAuthorized ? "Notifications enabled" : "Notifications disabled",
                          systemImage: viewModel.notificationsAuthorized ? "bell.badge" : "bell.slash")
                        .foregroundStyle(viewModel.notificationsAuthorized ? .green : .orange)
                    Spacer()
                }
                Label("Scheduled reminders: \(viewModel.pendingReminderCount)", systemImage: "calendar.badge.clock")
                Button("Request permission", action: requestNotifications)
                Button("Schedule test reminder", action: scheduleTestReminder)
                Button("Refresh reminder count") {
                    Task { await viewModel.refreshPendingReminderCount() }
                }
                Button("Regenerate next 7 days") {
                    Task { await viewModel.regenerateSchedule() }
                }
            }

            Section("Data") {
                Button("Export data", action: exportData)
                if let url = viewModel.lastExportURL {
                    ShareLink(item: url) {
                        Label("Share last export", systemImage: "square.and.arrow.up")
                    }
                }
                Button("Import data from file") {
                    showingImporter = true
                }
            }

            Section("Danger Zone") {
                Button(role: .destructive) {
                    showingResetConfirmation = true
                } label: {
                    Label("Reset all data", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Settings")
        .task {
            await viewModel.configure(app: app)
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case let .success(url):
                Task { await viewModel.importData(from: url) }
            case let .failure(error):
                alertMessage = "Import failed: \(error.localizedDescription)"
            }
        }
        .alert("Reset Move?", isPresented: $showingResetConfirmation, actions: {
            Button("Cancel", role: .cancel, action: {})
            Button("Reset", role: .destructive) {
                Task { await viewModel.resetData(context: modelContext) }
            }
        }, message: {
            Text("This removes all exercises, schedules, and history, then restores the default seed data.")
        })
        .onChange(of: viewModel.alertMessage) { newValue in
            alertMessage = newValue
        }
        .alert(alertMessage ?? "", isPresented: Binding(get: { alertMessage != nil }, set: { newValue in
            if !newValue { alertMessage = nil }
        })) {
            Button("OK", role: .cancel) { alertMessage = nil }
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

    private func exportData() {
        Task {
            await viewModel.exportData()
        }
    }
}

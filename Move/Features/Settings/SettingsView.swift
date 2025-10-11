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
    @AppStorage(MoveTheme.Preference.storageKey) private var themePreferenceRawValue = MoveTheme.Preference.fallback.rawValue

    private var themePreference: MoveTheme.Preference {
        get { MoveTheme.Preference(rawValue: themePreferenceRawValue) ?? .fallback }
        set { themePreferenceRawValue = newValue.rawValue }
    }

    var body: some View {
        Form {
            Section("APPEARANCE") {
                Picker("Color mode", selection: Binding(get: { themePreference }, set: { themePreferenceRawValue = $0.rawValue })) {
                    ForEach(MoveTheme.Preference.allCases) { preference in
                        Text(preference.displayName).tag(preference)
                    }
                }
                .pickerStyle(.segmented)
                Text("Pick the palette that fits your space. Black dominates Light Mode while Dark Mode brightens backgrounds for maximum contrast.")
                    .font(.footnote)
                    .foregroundStyle(MoveTheme.muted)
            }

            Section("NOTIFICATIONS") {
                HStack {
                    Label(viewModel.notificationsAuthorized ? "Notifications enabled" : "Notifications disabled",
                          systemImage: viewModel.notificationsAuthorized ? "bell.badge" : "bell.slash")
                        .foregroundStyle(viewModel.notificationsAuthorized ? .green : .orange)
                    Spacer()
                }
                Label("Scheduled reminders: \(viewModel.pendingReminderCount)", systemImage: "calendar.badge.clock")
                Button("REQUEST PERMISSION", action: requestNotifications)
                Button("SCHEDULE TEST REMINDER", action: scheduleTestReminder)
                Button("REFRESH REMINDER COUNT") {
                    Task { await viewModel.refreshPendingReminderCount() }
                }
                Button("REGENERATE NEXT 7 DAYS") {
                    Task { await viewModel.regenerateSchedule() }
                }
            }

            Section("DATA") {
                Button("EXPORT DATA", action: exportData)
                if let url = viewModel.lastExportURL {
                    ShareLink(item: url) {
                        Label("Share last export", systemImage: "square.and.arrow.up")
                    }
                }
                Button("IMPORT DATA FROM FILE") {
                    showingImporter = true
                }
            }

            Section("DANGER ZONE") {
                Button(role: .destructive) {
                    showingResetConfirmation = true
                } label: {
                    Label("RESET ALL DATA", systemImage: "trash")
                }
            }
        }
        .listRowBackground(MoveTheme.background)
        .scrollContentBackground(.hidden)
        .background(MoveTheme.canvas.ignoresSafeArea())
        .navigationTitle("SETTINGS")
        .tint(MoveTheme.primary)
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
        .onChange(of: viewModel.alertMessage) { _, newValue in
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

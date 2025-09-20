import SwiftData
import SwiftUI

@main
struct MoveApp: App {
    @StateObject private var appStartup = AppStartup()
    @AppStorage(MoveTheme.Preference.storageKey) private var themePreferenceRawValue = MoveTheme.Preference.fallback.rawValue

    private var themePreference: MoveTheme.Preference {
        MoveTheme.Preference(rawValue: themePreferenceRawValue) ?? .fallback
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(appStartup)
                .modelContainer(appStartup.container)
                .preferredColorScheme(themePreference.colorScheme)
                .task {
                    await appStartup.configureIfNeeded()
                }
        }
    }
}

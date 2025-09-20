import SwiftData
import SwiftUI

@main
struct MoveApp: App {
    @StateObject private var appStartup = AppStartup()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(appStartup)
                .modelContainer(appStartup.container)
                .task {
                    await appStartup.configureIfNeeded()
                }
        }
    }
}

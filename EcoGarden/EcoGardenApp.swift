import SwiftUI

@main
struct EcoGardenApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                // Palette is designed for light mode.
                .preferredColorScheme(.light)
                .tint(Theme.moss)
        }
    }
}

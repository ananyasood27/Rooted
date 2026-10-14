import SwiftUI

@main
struct EcoGardenApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                // The palette is designed for a light background, so the app stays light
                // even when the phone is in dark mode (dark text on dark cards otherwise).
                .preferredColorScheme(.light)
                .tint(Theme.moss)
        }
    }
}

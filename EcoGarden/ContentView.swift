import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.hasOnboarded {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: appState.hasOnboarded)
    }
}

private struct MainTabView: View {
    var body: some View {
        TabView {
            TaskListView()
                .tabItem { Label("Tasks", systemImage: "checklist") }

            GardenView()
                .tabItem { Label("Garden", systemImage: "leaf.fill") }

            ShopView()
                .tabItem { Label("Shop", systemImage: "cart.fill") }
        }
        .tint(Theme.moss)
    }
}

#Preview {
    ContentView().environmentObject(AppState())
}

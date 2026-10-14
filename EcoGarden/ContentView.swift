import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isLoggedIn {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: appState.isLoggedIn)
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

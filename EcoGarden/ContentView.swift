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

/// The three tabs. Kept in AppState so any screen can switch tabs.
enum AppTab: Hashable {
    case doGood, community, shop
}

/// The two halves of the Do Good tab.
enum DoGoodSegment: Hashable {
    case habits, volunteer
}

private struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            DoGoodView()
                .tabItem { Label("Do Good", systemImage: "hand.raised.fill") }
                .tag(AppTab.doGood)

            GardenView()
                .tabItem { Label("Community", systemImage: "house.and.flag.fill") }
                .tag(AppTab.community)

            ShopView()
                .tabItem { Label("Shop", systemImage: "cart.fill") }
                .tag(AppTab.shop)
        }
        .tint(Theme.moss)
        // Level-ups, weekly challenge wins and new street upgrades, from any screen.
        .overlay(alignment: .top) {
            if let message = appState.celebrations.first {
                CelebrationBanner(text: message)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(message)
                    .task(id: message) {
                        try? await Task.sleep(nanoseconds: 3_800_000_000)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if !appState.celebrations.isEmpty { appState.celebrations.removeFirst() }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.celebrations)
    }
}

/// A short gold banner for good news. Tap to dismiss early.
struct CelebrationBanner: View {
    @EnvironmentObject var appState: AppState
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18))
                .foregroundColor(Theme.sunflower)
            Text(text)
                .font(Theme.display(14, weight: .semibold))
                .foregroundColor(Theme.bark)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                .strokeBorder(Theme.sunflower.opacity(0.6), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .onTapGesture {
            withAnimation { if !appState.celebrations.isEmpty { appState.celebrations.removeFirst() } }
        }
    }
}

#Preview {
    ContentView().environmentObject(AppState())
}

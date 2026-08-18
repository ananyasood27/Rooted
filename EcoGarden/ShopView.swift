import SwiftUI

struct ShopView: View {
    @EnvironmentObject var appState: AppState

    let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(appState.shopItems) { item in
                            ShopItemCard(item: item)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(
                LinearGradient(
                    colors: [Theme.skyWash, Theme.sunflower.opacity(0.08)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    CoinBadge(amount: appState.coins)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Shop")
                .font(Theme.display(26))
                .foregroundColor(Theme.bark)
            Text("Spend EcoCoins to grow your garden.")
                .font(Theme.body(14))
                .foregroundColor(Theme.stone)
        }
    }
}

private struct ShopItemCard: View {
    @EnvironmentObject var appState: AppState
    let item: GardenItem
    @State private var showCantAfford = false
    @State private var justBought = false

    private var canAfford: Bool { appState.coins >= item.cost }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [item.color.opacity(0.22), item.color.opacity(0.08)],
                            center: .center, startRadius: 2, endRadius: 34
                        )
                    )
                    .frame(width: 60, height: 60)
                Image(systemName: item.icon)
                    .font(.system(size: 25))
                    .foregroundColor(item.color)
            }

            Text(item.name)
                .font(Theme.display(13, weight: .semibold))
                .foregroundColor(Theme.bark)

            Button {
                let bought = appState.buyItem(item)
                if bought {
                    justBought = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { justBought = false }
                } else {
                    showCantAfford = true
                }
            } label: {
                HStack(spacing: 4) {
                    Circle().fill(Theme.sunflower).frame(width: 10, height: 10)
                        .overlay(Image(systemName: "leaf.fill").font(.system(size: 5, weight: .bold)).foregroundColor(Theme.moss))
                    Text("\(item.cost)")
                        .font(Theme.caption())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(canAfford ? Theme.moss : Theme.stone.opacity(0.22)))
                .foregroundColor(canAfford ? .white : Theme.stone)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Buy \(item.name) for \(item.cost) coins")
            .alert("Not enough EcoCoins", isPresented: $showCantAfford) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Complete more tasks to earn coins for \(item.name.lowercased()).")
            }
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(item.color.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Theme.bark.opacity(0.05), radius: 8, y: 3)
        .scaleEffect(justBought ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: justBought)
    }
}

#Preview {
    ShopView().environmentObject(AppState())
}

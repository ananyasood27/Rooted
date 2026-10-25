import SwiftUI

struct ShopView: View {
    @EnvironmentObject var appState: AppState

    let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]
    @State private var justPlanted: GardenItem? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                header.greenHeader()

                VStack(alignment: .leading, spacing: 18) {
                    SectionLabel(text: "Plants & garden items")
                        .padding(.bottom, -6)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(appState.shopItems) { item in
                            ShopItemCard(item: item) { bought in showPlanted(bought) }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .background(ScreenBackground())
            .greenNavigationBar()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                HeaderToolbarItem(placement: .navigationBarTrailing) {
                    CoinBadge(amount: appState.coins, onDark: true)
                }
            }
            .overlay(alignment: .bottom) {
                if let item = justPlanted {
                    plantedToast(item)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private func showPlanted(_ item: GardenItem) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { justPlanted = item }
        let shown = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            // Only hide it if a newer purchase hasn't replaced it.
            if justPlanted?.id == shown {
                withAnimation(.easeInOut(duration: 0.3)) { justPlanted = nil }
            }
        }
    }

    private func plantedToast(_ item: GardenItem) -> some View {
        HStack(spacing: 12) {
            PlantSprite(kind: item.kind, stage: 0, size: 34)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text("Planted your \(item.name)!")
                    .font(Theme.display(14, weight: .semibold))
                    .foregroundColor(Theme.bark)
                Text("It's waiting in your yard.")
                    .font(Theme.body(12))
                    .foregroundColor(Theme.stone)
            }
            Spacer()
            Button {
                withAnimation { justPlanted = nil }
                appState.selectedTab = .community
            } label: {
                Text("See it")
                    .font(Theme.caption(13))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.moss))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(Theme.sunflower.opacity(0.6), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Shop")
                .font(Theme.heading(24))
                .foregroundColor(.white)
            Text("Spend EcoCoins to grow your garden.")
                .font(Theme.body(14))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

private struct ShopItemCard: View {
    @EnvironmentObject var appState: AppState
    let item: GardenItem
    let onBought: (GardenItem) -> Void
    @State private var showCantAfford = false
    @State private var justBought = false

    private var canAfford: Bool { appState.coins >= item.cost }

    // use the same colors as the task cards
    private var cardTint: Color {
        switch item.tintColor {
        case "yellow": return Theme.sunflower
        case "brown": return EcoTaskKind.compost.tint
        case "blue": return EcoTaskKind.water.tint
        default: return EcoTaskKind.reusable.tint
        }
    }

    private var previewScale: CGFloat {
        let art = item.kind.footprint(stage: 3)
        return min(112 / art.width, 108 / art.height, 1.7)
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(Theme.sage.opacity(0.30))
                    .frame(width: 70, height: 14)
                PlantSprite(kind: item.kind, stage: 3, size: 66)
                    .scaleEffect(previewScale, anchor: PlantSprite.groundAnchor)
            }
            .frame(height: 76)

            Text(item.name)
                .font(Theme.display(13, weight: .semibold))
                .foregroundColor(Theme.bark)

            Button {
                let bought = appState.buyItem(item)
                if bought {
                    onBought(item)
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
        .ecoCard(tint: cardTint)
        .scaleEffect(justBought ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: justBought)
    }
}

#Preview {
    ShopView().environmentObject(AppState())
}

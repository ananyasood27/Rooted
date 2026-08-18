import SwiftUI

/// About/mission page — helps judges (and any user) quickly understand
/// what the app does and why, without digging through the UI.
struct InfoView: View {
@EnvironmentObject var appState: AppState
@Environment(\.dismiss) private var dismiss

var body: some View {
NavigationView {
ScrollView {
VStack(alignment: .leading, spacing: 22) {
heroSection

InfoSection(
icon: "leaf.fill",
title: "What is EcoGarden?",
text: "EcoGarden turns everyday sustainability habits — recycling, composting, reusing, reducing waste — into a living virtual garden. Complete real tasks, earn EcoCoins, and grow a garden that reflects the consistency of your habits."
)

InfoSection(
icon: "checkmark.circle.fill",
title: "How it works",
text: "Complete tasks in the Tasks tab to earn coins — you can repeat tasks daily for a growing bonus. Spend coins in the Shop on plants and garden items, then place them anywhere in your yard. Water your plants to keep them healthy and help them grow through four stages, from sprout to full bloom."
)

InfoSection(
icon: "flame.fill",
title: "Streaks",
text: "Clear every task at least once in a day to earn a bonus and build your streak. Consistency is the whole point — small daily actions compound into a garden (and a habit) that actually grows."
)

localImpactSection

statsSection

InfoSection(
icon: "info.circle.fill",
title: "Why it matters",
text: "Individually small actions — recycling a bottle, composting scraps, biking instead of driving — add up when done consistently. EcoGarden makes that consistency visible and rewarding, instead of invisible and easy to forget."
)
}
.padding(20)
}
.background(Theme.skyWash.ignoresSafeArea())
.navigationBarTitleDisplayMode(.inline)
.toolbar {
ToolbarItem(placement: .navigationBarTrailing) {
Button("Done") { dismiss() }
.foregroundColor(Theme.moss)
.fontWeight(.semibold)
}
}
}
}

private var heroSection: some View {
VStack(spacing: 10) {
ZStack {
Circle().fill(Theme.moss.opacity(0.10)).frame(width: 84, height: 84)
Image(systemName: "leaf.fill")
.font(.system(size: 34))
.foregroundColor(Theme.moss)
.rotationEffect(.degrees(-8))
}
Text("EcoGarden")
.font(Theme.display(26))
.foregroundColor(Theme.bark)
Text("Small habits. A garden that grows with you.")
.font(Theme.body(13))
.foregroundColor(Theme.stone)
}
.frame(maxWidth: .infinity)
.padding(.bottom, 4)
}

private var localImpactSection: some View {
VStack(alignment: .leading, spacing: 10) {
HStack(spacing: 8) {
Image(systemName: "mappin.and.ellipse")
.foregroundColor(Theme.moss)
Text("Local Impact")
.font(Theme.display(16, weight: .semibold))
.foregroundColor(Theme.bark)
}
Text("Each task links to a real local resource. Open a task in the Tasks tab and tap it to see the tip.")
.font(Theme.body(13))
.foregroundColor(Theme.stone)
.fixedSize(horizontal: false, vertical: true)
}
.padding(16)
.frame(maxWidth: .infinity, alignment: .leading)
.ecoCard()
}

private var statsSection: some View {
HStack(spacing: 10) {
StatTile(label: "Day Streak", value: "\(appState.streak)", icon: "flame.fill", color: Color(red: 0.85, green: 0.45, blue: 0.20))
StatTile(label: "Planted", value: "\(appState.placedItems.count)", icon: "leaf.fill", color: Theme.moss)
StatTile(label: "EcoCoins", value: "\(appState.coins)", icon: "circle.fill", color: Theme.sunflower)
}
}
}

private struct InfoSection: View {
let icon: String
let title: String
let text: String // renamed from `body` to avoid conflict with View's `body` property

var body: some View {
VStack(alignment: .leading, spacing: 8) {
HStack(spacing: 8) {
Image(systemName: icon)
.foregroundColor(Theme.moss)
Text(title)
.font(Theme.display(16, weight: .semibold))
.foregroundColor(Theme.bark)
}
Text(text)
.font(Theme.body(14))
.foregroundColor(Theme.stone)
.fixedSize(horizontal: false, vertical: true)
}
.padding(16)
.frame(maxWidth: .infinity, alignment: .leading)
.ecoCard()
}
}

private struct StatTile: View {
let label: String
let value: String
let icon: String
let color: Color

var body: some View {
VStack(spacing: 6) {
Image(systemName: icon)
.foregroundColor(color)
Text(value)
.font(Theme.display(18, weight: .bold))
.foregroundColor(Theme.bark)
Text(label)
.font(Theme.caption(10))
.foregroundColor(Theme.stone)
}
.frame(maxWidth: .infinity)
.padding(.vertical, 12)
.ecoCard()
}
}

#Preview {
InfoView().environmentObject(AppState())
}

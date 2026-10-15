import SwiftUI

/// About/mission page — helps judges (and any user) quickly understand
/// what the app does and why, without digging through the UI.
struct InfoView: View {
@EnvironmentObject var appState: AppState
@Environment(\.dismiss) private var dismiss
@State private var showNotificationsDenied = false

var body: some View {
NavigationStack {
ScrollView {
VStack(alignment: .leading, spacing: 22) {
heroSection

InfoSection(
icon: "leaf.fill",
title: "What is EcoGarden?",
text: "EcoGarden turns everyday good — recycling, composting, saving water, volunteering — into a living community. Look after the planet and your garden grows. Volunteer around Baytown and the places on your street get built. Stop showing up and they go quiet."
)

InfoSection(
icon: "checkmark.circle.fill",
title: "How it works",
text: "Complete eco tasks in the Do Good tab to earn coins — you can repeat tasks daily for a growing bonus, and attach a photo as proof. Spend coins in the Shop on plants and garden items, then drag them anywhere in your yard. Everything grows through four levels when you look after it: water plants, turn compost, fill rain barrels and feed butterflies. Composting and saving water in real life tend your Compost Bins and Rain Barrels for free. Leave the garden alone too long and it starts to wilt.\n\nIn Do Good → Volunteer, log hours at real Baytown organizations. Each kind of volunteering builds a place on the street behind your yard — an animal shelter, library, nature center, food bank and neighborhood — from an empty lot up to a thriving building. A place stays lively for two weeks after you last volunteered for it.\n\nThe two halves work together: your eco habits add green upgrades to the same street — bike racks, recycling bins, a community garden — and every eco task and volunteer hour fills one Community Level that adds trees, streetlights, flags and a festival. Each week there's a challenge that needs both."
)

InfoSection(
icon: "flame.fill",
title: "Streaks",
text: "Clear every task at least once in a day to earn a bonus and build your streak. Consistency is the whole point — small daily actions compound into a garden (and a habit) that actually grows."
)

localImpactSection

impactSection

statsSection

remindersSection

accountSection

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
Text("Small acts. A community that grows with you.")
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
Text("EcoGarden is built for Baytown, Texas. Every task points to a real local resource — the city's Green Center, curbside recycling, the Goose Creek Trail, Harris County Transit — and Do Good → Volunteer lists real Baytown programs like the animal shelter, the library's teen volunteers and the wetlands center. Tap a task in Do Good to see its tip and open the official page.")
.font(Theme.body(13))
.foregroundColor(Theme.stone)
.fixedSize(horizontal: false, vertical: true)
}
.padding(16)
.frame(maxWidth: .infinity, alignment: .leading)
.ecoCard()
}

private var impactSection: some View {
VStack(alignment: .leading, spacing: 10) {
HStack(spacing: 8) {
Image(systemName: "globe.americas.fill")
.foregroundColor(Theme.moss)
Text("Your Impact")
.font(Theme.display(16, weight: .semibold))
.foregroundColor(Theme.bark)
}
ImpactTiles(impact: appState.impact)
Text("How this is estimated: each walk or bike trip counts as a 2-mile car trip avoided, at the EPA's average of about 400 grams of CO₂ per mile. Each water task counts as a shower 2 minutes shorter, at the federal standard showerhead flow of 2.5 gallons per minute (EPA WaterSense). Recycling, composting, reusing and donating each count as one item kept out of the landfill.")
.font(Theme.body(11.5))
.foregroundColor(Theme.stone)
.fixedSize(horizontal: false, vertical: true)
}
.padding(16)
.frame(maxWidth: .infinity, alignment: .leading)
.ecoCard()
}

private var remindersSection: some View {
VStack(alignment: .leading, spacing: 10) {
// The toggle can't write to appState directly, because switching it on has to wait
// for the system permission prompt — so it goes through setReminders instead.
Toggle(isOn: Binding(
get: { appState.remindersEnabled },
set: { wantsOn in
appState.setReminders(wantsOn, denied: { showNotificationsDenied = true })
}
)) {
HStack(spacing: 8) {
Image(systemName: "bell.fill")
.foregroundColor(Theme.moss)
Text("Reminders")
.font(Theme.display(16, weight: .semibold))
.foregroundColor(Theme.bark)
}
}
.tint(Theme.moss)
Text("A nudge at 6 PM to finish your tasks, and an alert when something in your garden needs care.")
.font(Theme.body(13))
.foregroundColor(Theme.stone)
.fixedSize(horizontal: false, vertical: true)
}
.padding(16)
.frame(maxWidth: .infinity, alignment: .leading)
.ecoCard()
.alert("Notifications are turned off", isPresented: $showNotificationsDenied) {
Button("OK", role: .cancel) { }
} message: {
Text("To get reminders, allow notifications for EcoGarden in the Settings app.")
}
}

// Logging out only locks the app — the garden and progress stay saved on the device.
private var accountSection: some View {
VStack(alignment: .leading, spacing: 10) {
HStack(spacing: 8) {
Image(systemName: "person.crop.circle.fill")
.foregroundColor(Theme.moss)
Text("Account")
.font(Theme.display(16, weight: .semibold))
.foregroundColor(Theme.bark)
}
Text("Signed in as \(AccountStore.load()?.username ?? appState.userName). Your account and garden are stored only on this device.")
.font(Theme.body(13))
.foregroundColor(Theme.stone)
.fixedSize(horizontal: false, vertical: true)
Button {
dismiss()
appState.logOut()
} label: {
Text("Log Out")
.font(Theme.display(14, weight: .semibold))
.foregroundColor(Theme.ember)
.padding(.horizontal, 16)
.padding(.vertical, 9)
.background(Capsule().fill(Theme.ember.opacity(0.12)))
}
.buttonStyle(.plain)
}
.padding(16)
.frame(maxWidth: .infinity, alignment: .leading)
.ecoCard()
}

private var statsSection: some View {
HStack(spacing: 10) {
StatTile(label: "Day Streak", value: "\(appState.streak)", icon: "flame.fill", color: Theme.ember)
StatTile(label: "Planted", value: "\(appState.placedItems.count)", icon: "leaf.fill", color: Theme.moss)
StatTile(label: "EcoCoins", value: "\(appState.coins)", icon: "circle.fill", color: Theme.sunflower)
}
}
}

/// The four headline impact numbers, shown on the Do Good tab and the About page.
struct ImpactTiles: View {
let impact: ImpactSummary

var body: some View {
VStack(spacing: 10) {
HStack(spacing: 10) {
StatTile(label: "CO₂ avoided", value: "\(Self.format(impact.co2Pounds)) lb", icon: "bicycle", color: Theme.moss)
StatTile(label: "Water saved", value: "\(Self.format(impact.gallons)) gal", icon: "drop.fill", color: Theme.water)
}
HStack(spacing: 10) {
StatTile(label: "Kept from landfill", value: "\(impact.itemsDiverted)", icon: "arrow.3.trianglepath", color: Theme.soil)
StatTile(label: "Volunteer hours", value: formatHours(impact.volunteerHours), icon: "hand.raised.fill", color: Theme.petal)
}
}
}

/// One decimal while the number is small, whole numbers after that.
private static func format(_ value: Double) -> String {
value < 10 && value != value.rounded() ? String(format: "%.1f", value) : String(format: "%.0f", value)
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
// Read as one item by VoiceOver ("5.4 lb, CO₂ avoided"), not three separate pieces.
.accessibilityElement(children: .combine)
}
}

#Preview {
InfoView().environmentObject(AppState())
}

import Foundation
import SwiftUI
import Combine

//Central source of truth for the app. Injected as an EnvironmentObject.
//Persists to UserDefaults as JSON — simple and reliable for a CAC-scale project.
class AppState: ObservableObject {

    @Published var tasks: [EcoTask] {
        didSet { save() }
    }
    @Published var coins: Int {
        didSet { save() }
    }
    @Published var placedItems: [PlacedItem] {
        didSet { save() }
    }
    @Published var userName: String {
        didSet { save() }
    }
    @Published var hasOnboarded: Bool {
        didSet { save() }
    }
    /// False until someone logs in; logging out sets it back. Saved, so you stay logged in.
    @Published var isLoggedIn: Bool {
        didSet { save() }
    }
    @Published var streak: Int {
        didSet { save() }
    }
    @Published var lastFullClearDate: Date? {
        didSet { save() }
    }
    /// Set briefly to true right after a full-clear bonus fires, so the UI can
    /// show a one-time celebration instead of a permanent banner every visit.
    @Published var justEarnedFullClearBonus: Bool = false
    /// All-time completions per habit (keyed by EcoTaskKind raw value) — feeds the impact numbers.
    @Published var lifetimeCompletions: [String: Int] {
        didSet { save() }
    }
    /// Whether the user has turned on reminder notifications (see Reminders.swift).
    @Published var remindersEnabled: Bool {
        didSet {
            save()
            refreshReminders()
        }
    }
    /// Demo mode: how far the garden's clock has been pushed ahead of the real one,
    /// so wilting and nightfall can be shown without waiting hours. Never saved.
    @Published var demoTimeOffset: TimeInterval = 0

    /// The garden's idea of "now" — the real time, plus any demo fast-forward.
    var now: Date { Date().addingTimeInterval(demoTimeOffset) }

    let shopItems = GardenItem.shopItems
    private let defaults = UserDefaults.standard

    private let tasksKey = "ecogarden.tasks"
    private let coinsKey = "ecogarden.coins"
    private let placedKey = "ecogarden.placedItems"
    private let nameKey = "ecogarden.userName"
    private let onboardedKey = "ecogarden.hasOnboarded"
    private let streakKey = "ecogarden.streak"
    private let lastClearKey = "ecogarden.lastFullClearDate"
    private let lifetimeKey = "ecogarden.lifetimeCompletions"
    private let loggedInKey = "ecogarden.isLoggedIn"
    private let remindersKey = "ecogarden.remindersEnabled"

    /// Number of repeats after which the combo bonus stops growing (still completable, just flat).
    private let comboCap = 4
    /// Fraction of base reward added per repeat, up to the cap.
    private let comboBonusRate = 0.25
    private let fullClearBonus = 20
    let wateringCost = 5
    /// Normalized vertical band of the garden canvas that is actually ground —
    /// above this is fence, hills and sky, where nothing can be planted.
    static let yardYRange: ClosedRange<Double> = 0.39...0.95

    init() {
        var movedOldPhotos = false
        if let data = defaults.data(forKey: tasksKey),
           let decoded = try? JSONDecoder().decode([EcoTask].self, from: data) {
            self.tasks = decoded.map { task in
                var t = task
                // Photos used to be saved inside this data; move any into files.
                if let oldPhoto = t.proofImageData {
                    t.proofFileName = ProofStore.save(oldPhoto)
                    t.proofDate = t.lastCompletedDate
                    t.proofImageData = nil
                    movedOldPhotos = true
                }
                if let last = t.lastCompletedDate, !Calendar.current.isDateInToday(last) {
                    t.completionsToday = 0
                }
                // Saved tasks keep their progress but pick up the current tips and links.
                if let current = EcoTask.starterTasks.first(where: { $0.title == t.title }) {
                    t.kind = current.kind
                    t.localTip = current.localTip
                    t.localURL = current.localURL
                }
                return t
            }
        } else {
            self.tasks = EcoTask.starterTasks
        }

        self.coins = defaults.integer(forKey: coinsKey)

        if let data = defaults.data(forKey: placedKey),
           let decoded = try? JSONDecoder().decode([PlacedItem].self, from: data) {
            // Items saved before shop IDs were stable point at IDs that no longer exist;
            // bring them back as seedlings rather than leaving them invisible. Also pull
            // anything that was parked up in the sky back down onto the lawn.
            let knownIDs = Set(GardenItem.shopItems.map(\.id))
            let fallbackID = GardenItem.shopItems[0].id
            self.placedItems = decoded.map { item in
                var p = item
                if !knownIDs.contains(p.itemID) { p.itemID = fallbackID }
                p.y = min(max(p.y, Self.yardYRange.lowerBound), Self.yardYRange.upperBound)
                return p
            }
        } else {
            self.placedItems = []
        }

        self.userName = defaults.string(forKey: nameKey) ?? ""
        self.hasOnboarded = defaults.bool(forKey: onboardedKey)
        self.isLoggedIn = defaults.bool(forKey: loggedInKey)
        self.remindersEnabled = defaults.bool(forKey: remindersKey)
        self.streak = defaults.integer(forKey: streakKey)
        self.lastFullClearDate = defaults.object(forKey: lastClearKey) as? Date
        self.lifetimeCompletions = defaults.dictionary(forKey: lifetimeKey) as? [String: Int] ?? [:]

        // If more than a full day was missed since the last clear, the streak breaks.
        if let last = lastFullClearDate {
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            let lastDay = cal.startOfDay(for: last)
            let daysBetween = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if daysBetween > 1 {
                self.streak = 0
            }
        }

        if movedOldPhotos { save() }
        refreshReminders()
    }

    // MARK: - Reminders

    /// Turning reminders on has to go through the system permission prompt first.
    /// `denied` is called if the user (now or earlier) said no to notifications.
    func setReminders(_ on: Bool, denied: @escaping () -> Void = {}) {
        guard on else {
            remindersEnabled = false
            return
        }
        Reminders.requestPermission { granted in
            self.remindersEnabled = granted
            if !granted { denied() }
        }
    }

    /// Re-plans the notifications so the "needs care" alert always matches the garden.
    private func refreshReminders() {
        if remindersEnabled {
            Reminders.schedule(for: placedItems)
        } else {
            Reminders.cancelAll()
        }
    }

    // MARK: - Account

    func logOut() {
        isLoggedIn = false
    }

    /// The only way back in after a forgotten password: wipe the account and everything
    /// saved with it, returning the app to how it was on first launch.
    func resetEverything() {
        AccountStore.delete()
        for task in tasks {
            if let photo = task.proofFileName { ProofStore.delete(named: photo) }
        }
        tasks = EcoTask.starterTasks
        coins = 0
        placedItems = []
        userName = ""
        streak = 0
        lastFullClearDate = nil
        lifetimeCompletions = [:]
        demoTimeOffset = 0
        remindersEnabled = false
        hasOnboarded = false
        isLoggedIn = false
    }

    // MARK: - Task actions

    /// The reward for the *next* completion of this task today — grows with repeats, then plateaus.
    func nextReward(for task: EcoTask) -> Int {
    let repeatIndex = max(0, min(task.completionsToday, comboCap)) // clamp to 0...comboCap
    let bonus = Double(task.coinReward) * comboBonusRate * Double(repeatIndex)
    return task.coinReward + Int(bonus)
    }

    /// Complete a task (repeatable). Awards a growing combo bonus for same-day repeats,
    /// then checks whether the whole list just got cleared for the first time today.
    /// `proofFile` is the name of a photo already saved with ProofStore, if one was attached.
    func completeTask(_ task: EcoTask, proofFile: String?) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }

        let reward = nextReward(for: tasks[index])
        tasks[index].completionsToday += 1
        tasks[index].lastCompletedDate = Date()
        if let proofFile {
            if let previous = tasks[index].proofFileName { ProofStore.delete(named: previous) }
            tasks[index].proofFileName = proofFile
            tasks[index].proofDate = Date()
        }
        if let kind = tasks[index].kind {
            lifetimeCompletions[kind.rawValue, default: 0] += 1
            // The first completion each day also tends the matching garden items.
            // Only the first, so repeating a task can't max out a garden in one sitting.
            if tasks[index].completionsToday == 1, let itemKind = kind.tendsItem {
                tendItems(of: itemKind)
            }
        }
        coins += reward

        checkFullClearBonus()
    }

    /// Estimated real-world effect of everything completed so far.
    var impact: ImpactSummary {
        var total = ImpactSummary()
        for (rawKind, count) in lifetimeCompletions {
            guard let kind = EcoTaskKind(rawValue: rawKind) else { continue }
            total.co2Pounds += kind.co2PoundsAvoided * Double(count)
            total.gallons += kind.gallonsSaved * Double(count)
            if kind.keepsItemOutOfLandfill { total.itemsDiverted += count }
        }
        return total
    }

    var allTasksCompletedToday: Bool {
        !tasks.isEmpty && tasks.allSatisfy { $0.completionsToday >= 1 }
    }

    private func checkFullClearBonus() {
        guard allTasksCompletedToday else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if let last = lastFullClearDate, cal.isDate(last, inSameDayAs: today) {
            return // already awarded today
        }

        // Streak continues only if the previous clear was exactly yesterday.
        if let last = lastFullClearDate {
            let lastDay = cal.startOfDay(for: last)
            let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
            streak = cal.isDate(lastDay, inSameDayAs: yesterday) ? streak + 1 : 1
        } else {
            streak = 1
        }

        lastFullClearDate = Date()
        coins += fullClearBonus
        justEarnedFullClearBonus = true
    }

    // MARK: - Garden actions

    @discardableResult
    func buyItem(_ item: GardenItem) -> Bool {
        guard coins >= item.cost else { return false }

        coins -= item.cost
        let spot = randomSpot()
        let placed = PlacedItem(
            itemID: item.id,
            x: spot.x,
            y: spot.y,
            rotation: Double.random(in: -8...8),
            scale: Double.random(in: 0.92...1.08),
            plantedDate: now,
            lastWateredDate: now
        )
        placedItems.append(placed)
        refreshReminders()
        return true
    }

    func moveItem(id: UUID, x: Double, y: Double) {
        guard let index = placedItems.firstIndex(where: { $0.id == id }) else { return }
        placedItems[index].x = min(max(x, 0.06), 0.94)
        placedItems[index].y = min(max(y, Self.yardYRange.lowerBound), Self.yardYRange.upperBound)
    }

    /// Free care for every placed item of one kind — the reward for doing the matching habit.
    private func tendItems(of kind: GardenItemKind) {
        let matchingIDs = Set(shopItems.filter { $0.kind == kind }.map(\.id))
        for index in placedItems.indices where matchingIDs.contains(placedItems[index].itemID) {
            placedItems[index].lastWateredDate = now
            placedItems[index].careCount += 1
        }
        refreshReminders()
    }

    /// Water a plant: costs coins, resets health to full, and advances growth stage.
    /// Returns false (no charge, no effect) if the user can't afford it.
    @discardableResult
    func waterItem(id: UUID) -> Bool {
        guard coins >= wateringCost else { return false }
        guard let index = placedItems.firstIndex(where: { $0.id == id }) else { return false }
        coins -= wateringCost
        placedItems[index].lastWateredDate = now
        placedItems[index].careCount += 1
        refreshReminders()
        return true
    }

    private func randomSpot() -> (x: Double, y: Double) {
        var best = (x: Double.random(in: 0.15...0.85), y: Double.random(in: 0.42...0.90))
        var bestDistance = -1.0

        for _ in 0..<8 {
            let candidate = (x: Double.random(in: 0.12...0.88), y: Double.random(in: 0.42...0.90))
            let minDist = placedItems.map { existing in
                let dx = existing.x - candidate.x
                let dy = existing.y - candidate.y
                return (dx * dx + dy * dy).squareRoot()
            }.min() ?? .infinity

            if minDist > bestDistance {
                bestDistance = minDist
                best = candidate
            }
        }
        return best
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(tasks) {
            defaults.set(data, forKey: tasksKey)
        }
        defaults.set(coins, forKey: coinsKey)
        if let data = try? JSONEncoder().encode(placedItems) {
            defaults.set(data, forKey: placedKey)
        }
        defaults.set(userName, forKey: nameKey)
        defaults.set(hasOnboarded, forKey: onboardedKey)
        defaults.set(streak, forKey: streakKey)
        defaults.set(lastFullClearDate, forKey: lastClearKey)
        defaults.set(lifetimeCompletions, forKey: lifetimeKey)
        defaults.set(isLoggedIn, forKey: loggedInKey)
        defaults.set(remindersEnabled, forKey: remindersKey)
    }
}

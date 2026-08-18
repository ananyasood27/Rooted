import Foundation
import SwiftUI
import Combine

/// Central source of truth for the app. Injected as an EnvironmentObject.
/// Persists to UserDefaults as JSON — simple and reliable for a CAC-scale project.
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
    @Published var streak: Int {
        didSet { save() }
    }
    @Published var lastFullClearDate: Date? {
        didSet { save() }
    }
    /// Set briefly to true right after a full-clear bonus fires, so the UI can
    /// show a one-time celebration instead of a permanent banner every visit.
    @Published var justEarnedFullClearBonus: Bool = false

    let shopItems = GardenItem.shopItems
    private let defaults = UserDefaults.standard

    private let tasksKey = "ecogarden.tasks"
    private let coinsKey = "ecogarden.coins"
    private let placedKey = "ecogarden.placedItems"
    private let nameKey = "ecogarden.userName"
    private let onboardedKey = "ecogarden.hasOnboarded"
    private let streakKey = "ecogarden.streak"
    private let lastClearKey = "ecogarden.lastFullClearDate"

    /// Number of repeats after which the combo bonus stops growing (still completable, just flat).
    private let comboCap = 4
    /// Fraction of base reward added per repeat, up to the cap.
    private let comboBonusRate = 0.25
    private let fullClearBonus = 20
    let wateringCost = 5

    init() {
        if let data = defaults.data(forKey: tasksKey),
           let decoded = try? JSONDecoder().decode([EcoTask].self, from: data) {
            self.tasks = decoded.map { task in
                var t = task
                if let last = t.lastCompletedDate, !Calendar.current.isDateInToday(last) {
                    t.completionsToday = 0
                }
                return t
            }
        } else {
            self.tasks = EcoTask.starterTasks
        }

        self.coins = defaults.integer(forKey: coinsKey)

        if let data = defaults.data(forKey: placedKey),
           let decoded = try? JSONDecoder().decode([PlacedItem].self, from: data) {
            self.placedItems = decoded
        } else {
            self.placedItems = []
        }

        self.userName = defaults.string(forKey: nameKey) ?? ""
        self.hasOnboarded = defaults.bool(forKey: onboardedKey)
        self.streak = defaults.integer(forKey: streakKey)
        self.lastFullClearDate = defaults.object(forKey: lastClearKey) as? Date

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
    }

    // MARK: - Task actions

    /// The reward for the *next* completion of this task today — grows with repeats, then plateaus.
    func nextReward(for task: EcoTask) -> Int {
        let repeatIndex = min(task.completionsToday, comboCap)
        let bonus = Int(Double(task.coinReward) * comboBonusRate) * repeatIndex
        return task.coinReward + bonus
    }

    /// Complete a task (repeatable). Awards a growing combo bonus for same-day repeats,
    /// then checks whether the whole list just got cleared for the first time today.
    func completeTask(_ task: EcoTask, proofImage: Data?) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }

        let reward = nextReward(for: tasks[index])
        tasks[index].completionsToday += 1
        tasks[index].lastCompletedDate = Date()
        if let proofImage { tasks[index].proofImageData = proofImage }
        coins += reward

        checkFullClearBonus()
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
            scale: Double.random(in: 0.92...1.08)
        )
        placedItems.append(placed)
        return true
    }

    func moveItem(id: UUID, x: Double, y: Double) {
        guard let index = placedItems.firstIndex(where: { $0.id == id }) else { return }
        placedItems[index].x = min(max(x, 0.06), 0.94)
        placedItems[index].y = min(max(y, 0.06), 0.94)
    }

    /// Water a plant: costs coins, resets health to full, and advances growth stage.
    /// Returns false (no charge, no effect) if the user can't afford it.
    @discardableResult
    func waterItem(id: UUID) -> Bool {
        guard coins >= wateringCost else { return false }
        guard let index = placedItems.firstIndex(where: { $0.id == id }) else { return false }
        coins -= wateringCost
        placedItems[index].lastWateredDate = Date()
        placedItems[index].careCount += 1
        return true
    }

    private func randomSpot() -> (x: Double, y: Double) {
        var best = (x: Double.random(in: 0.15...0.85), y: Double.random(in: 0.15...0.85))
        var bestDistance = -1.0

        for _ in 0..<8 {
            let candidate = (x: Double.random(in: 0.12...0.88), y: Double.random(in: 0.15...0.88))
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
    }
}

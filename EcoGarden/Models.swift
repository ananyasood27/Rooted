import Foundation
import SwiftUI

// MARK: - Sustainability Task

struct EcoTask: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var description: String
    var coinReward: Int
    var icon: String // SF Symbol name
    var localTip: String = "" // ties the task to a real local resource/program

    // Repeatable per day — tracks how many times this was done today
    var completionsToday: Int = 0
    var lastCompletedDate: Date? = nil
    var proofImageData: Data? = nil // most recent photo proof
}

// Starter task list — expand this however you like.
// TODO: Replace each localTip with a real resource for your city/district —
// this is the single biggest thing that makes the app feel rooted in your community
// rather than generic. A council/city sanitation department website is a good source.
extension EcoTask {
    static let starterTasks: [EcoTask] = [
        EcoTask(title: "Recycle Something", description: "Recycle plastic, paper, or glass today.", coinReward: 10, icon: "arrow.3.trianglepath", localTip: "Check your city's curbside recycling guide — many rejections happen from items that seem recyclable but aren't accepted locally."),
        EcoTask(title: "Compost Food Scraps", description: "Compost instead of trashing food waste.", coinReward: 15, icon: "leaf.fill", localTip: "Look up whether your city or county runs a community compost drop-off — many areas have one even without curbside pickup."),
        EcoTask(title: "Reusable Bag/Bottle", description: "Use a reusable bag or water bottle today.", coinReward: 5, icon: "bag.fill", localTip: "Some cities offer discounts for bringing reusable bags — check local grocery store policies."),
        EcoTask(title: "Donate an Item", description: "Donate clothes, books, or household items.", coinReward: 20, icon: "gift.fill", localTip: "Find a donation center or thrift store near you rather than the trash — most areas have several nonprofit drop-off points."),
        EcoTask(title: "Reduce Water Use", description: "Take a shorter shower or fix a leak.", coinReward: 10, icon: "drop.fill", localTip: "Many water utilities offer free leak-detection kits or rebates for low-flow fixtures — worth checking your local utility's site."),
        EcoTask(title: "Walk or Bike Instead of Drive", description: "Skip the car for a short trip.", coinReward: 15, icon: "bicycle", localTip: "Check if your city has bike lanes or a bike-share program near you.")
    ]
}

// MARK: - Garden Item (shop item the user can buy & place)

struct GardenItem: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var cost: Int
    var icon: String // SF Symbol used as a placeholder sprite
    var tintColor: String // stored as a string, mapped to Color below

    var color: Color {
        switch tintColor {
        case "green": return .green
        case "brown": return .brown
        case "blue": return .blue
        case "yellow": return .yellow
        default: return .green
        }
    }
}

extension GardenItem {
    static let shopItems: [GardenItem] = [
        GardenItem(name: "Seedling", cost: 10, icon: "leaf.fill", tintColor: "green"),
        GardenItem(name: "Flower", cost: 25, icon: "camera.macro", tintColor: "yellow"),
        GardenItem(name: "Tree", cost: 50, icon: "tree.fill", tintColor: "green"),
        GardenItem(name: "Compost Bin", cost: 40, icon: "trash.fill", tintColor: "brown"),
        GardenItem(name: "Rain Barrel", cost: 45, icon: "cloud.rain.fill", tintColor: "blue"),
        GardenItem(name: "Butterfly", cost: 30, icon: "ant.fill", tintColor: "yellow")
    ]
}

// A placed instance of a GardenItem, positioned freely in the garden.
// x and y are normalized (0...1) so placement scales with any canvas size.
struct PlacedItem: Identifiable, Codable {
    var id: UUID = UUID()
    var itemID: UUID
    var x: Double
    var y: Double
    var rotation: Double = 0 // slight random tilt so items don't look robotically aligned
    var scale: Double = 1.0

    var plantedDate: Date = Date()
    var lastWateredDate: Date = Date()
    var careCount: Int = 0 // number of times watered — drives growth stage
}

extension PlacedItem {
    /// Hours it takes for a fully-watered plant to wilt completely without care.
    static let decayWindowHours: Double = 18.0

    /// 0 (wilted) ... 100 (freshly watered), computed from elapsed time — no timers needed.
    func health(asOf date: Date = Date()) -> Double {
        let hoursSinceWater = date.timeIntervalSince(lastWateredDate) / 3600
        let raw = 100 - (hoursSinceWater / Self.decayWindowHours) * 100
        return min(100, max(0, raw))
    }

    /// Growth stage 0...3, driven by cumulative care rather than current health,
    /// so a plant's maturity reflects long-term tending, not just "did you water today."
    var stage: Int {
        switch careCount {
        case 0: return 0
        case 1...2: return 1
        case 3...5: return 2
        default: return 3
        }
    }
}

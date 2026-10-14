import Foundation
import SwiftUI

// MARK: - Sustainability Task

/// Which habit a task is — stable across launches, so impact can be tallied per habit.
enum EcoTaskKind: String, Codable {
    case recycle, compost, reusable, donate, water, travel
}

struct EcoTask: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var description: String
    var coinReward: Int
    var icon: String // SF Symbol name
    var localTip: String = "" // ties the task to a real local resource/program
    // Optional so tasks saved by older versions of the app still decode.
    var localURL: String? = nil // official page behind the tip
    var kind: EcoTaskKind? = nil

    // Repeatable per day — tracks how many times this was done today
    var completionsToday: Int = 0
    var lastCompletedDate: Date? = nil
    var proofFileName: String? = nil // most recent photo proof — a file kept by ProofStore
    var proofDate: Date? = nil
    /// Where older versions kept the photo itself. Only read once, to move it into a file.
    var proofImageData: Data? = nil
}

// Starter task list — expand this however you like.
// Local tips are for Baytown, Texas, taken from the City of Baytown, Harris County Transit,
// Goodwill Houston and City of Houston websites (checked October 2026). Hours, fees and phone
// numbers change — re-check them against each localURL before submitting.
extension EcoTask {
    static let starterTasks: [EcoTask] = [
        EcoTask(
            title: "Recycle Something", description: "Recycle plastic, paper, or glass today.", coinReward: 10, icon: "arrow.3.trianglepath",
            localTip: "Baytown picks up recycling at the curb once a week — carts out by 7 AM. No cart? Call Public Works at 281-420-5300. Cardboard, glass, cans and old electronics can also go to the Green Center, 1601 W Main (Tue–Fri 12–7, Sat 9–4; bring your ID and water bill).",
            localURL: "https://www.baytown.org/295", kind: .recycle),
        EcoTask(
            title: "Compost Food Scraps", description: "Compost instead of trashing food waste.", coinReward: 15, icon: "leaf.fill",
            localTip: "Baytown has no food-scrap pickup, so a backyard bin or pile is the simplest way. Houston-area services like Zero Waste Houston and Moonshot Compost also take food scraps at drop-off sites for a monthly fee. Yard trimmings: the city's weekly brush pickup, or the Green Center at 1601 W Main (grass in paper bags only).",
            localURL: "https://www.houstontx.gov/council/5/composting.html", kind: .compost),
        EcoTask(
            title: "Reusable Bag/Bottle", description: "Use a reusable bag or water bottle today.", coinReward: 5, icon: "bag.fill",
            localTip: "Plastic bags aren't on the Baytown Green Center's recycling list — it takes #1 and #2 plastic containers. Bringing your own bag or bottle is how you keep them out of the trash.",
            localURL: "https://baytown.org/1227", kind: .reusable),
        EcoTask(
            title: "Donate an Item", description: "Donate clothes, books, or household items.", coinReward: 20, icon: "gift.fill",
            localTip: "Goodwill Thrift Store & Donation Center, 3501 Garth Rd Suite 100 in Baytown, is open 9 AM–9 PM every day (281-420-2507). Clothes too worn to donate can go to textile recycling at the Green Center, 1601 W Main.",
            localURL: "https://www.goodwillhouston.org/locations/baytown", kind: .donate),
        EcoTask(
            title: "Reduce Water Use", description: "Take a shorter shower or fix a leak.", coinReward: 10, icon: "drop.fill",
            localTip: "The City of Baytown's leak checks: put food coloring in the toilet tank and wait 20 minutes — color in the bowl means a leak. Or turn off all the water and watch your meter for 15 minutes; if it moves, something is running.",
            localURL: "https://www.baytown.org/Blog.aspx?IID=282", kind: .water),
        EcoTask(
            title: "Walk or Bike Instead of Drive", description: "Skip the car for a short trip.", coinReward: 15, icon: "bicycle",
            localTip: "The Goose Creek Trail runs 6.25 miles along Goose Creek and Tabbs Bay and connects to Sterling Municipal Library and the Baytown Community Center. Too far to bike? Harris County Transit's Baytown buses are $1 a ride.",
            localURL: "https://baytown.org/865/Trails", kind: .travel)
    ]
}

// MARK: - Impact estimates

/// Deliberately conservative per-completion estimates. The assumptions and sources are
/// spelled out for the user on the About page — keep the two in sync.
extension EcoTaskKind {
    /// One walk/bike trip = a 2-mile car trip avoided, at the EPA's average of
    /// about 400 g of CO₂ per mile (800 g ≈ 1.8 lb).
    var co2PoundsAvoided: Double { self == .travel ? 1.8 : 0 }

    /// One water task = a shower 2 minutes shorter, at the federal standard
    /// showerhead flow of 2.5 gallons per minute.
    var gallonsSaved: Double { self == .water ? 5 : 0 }

    /// Counted as one item, with no weight claimed.
    var keepsItemOutOfLandfill: Bool {
        self == .recycle || self == .compost || self == .reusable || self == .donate
    }
}

// MARK: - Habits that tend the garden

/// Some garden items stand for a real habit, so doing that habit looks after them for free:
/// composting turns your Compost Bins, saving water fills your Rain Barrels.
extension EcoTaskKind {
    var tendsItem: GardenItemKind? {
        switch self {
        case .compost: return .compostBin
        case .water: return .rainBarrel
        default: return nil
        }
    }

    /// Shown on the task so the link to the garden is visible before you complete it.
    var gardenBonusText: String? {
        switch self {
        case .compost: return "First one today turns every Compost Bin for free"
        case .water: return "First one today fills every Rain Barrel for free"
        default: return nil
        }
    }
}

struct ImpactSummary {
    var co2Pounds: Double = 0
    var gallons: Double = 0
    var itemsDiverted: Int = 0
}

// MARK: - Garden Item (shop item the user can buy & place)

/// What an item *is* — drives which art gets drawn for it and what its growth stages are called.
enum GardenItemKind: String, Codable {
    case seedling, flower, tree, compostBin, rainBarrel, butterfly

    /// Display name for each of the four growth stages (index 0...3).
    var stageNames: [String] {
        switch self {
        case .seedling: return ["Sprout", "Seedling", "Bush", "Berry Bush"]
        case .flower: return ["Sprout", "Bud", "Bloom", "Bouquet"]
        case .tree: return ["Sprout", "Sapling", "Young Tree", "Grand Tree"]
        case .compostBin: return ["Empty", "Filling", "Composting", "Rich Soil"]
        case .rainBarrel: return ["Empty", "Collecting", "Filling", "Overflowing"]
        case .butterfly: return ["Egg", "Caterpillar", "Chrysalis", "Butterfly"]
        }
    }

    /// What tending this item is called — you water a plant, but you turn compost,
    /// fill a rain barrel and feed a butterfly.
    var careVerb: String {
        switch self {
        case .compostBin: return "Turn"
        case .butterfly: return "Feed"
        case .rainBarrel: return "Fill"
        default: return "Water"
        }
    }

    /// The same action as a noun, for "Feeding costs 5 coins".
    var careGerund: String {
        switch self {
        case .compostBin: return "Turning"
        case .butterfly: return "Feeding"
        case .rainBarrel: return "Filling"
        default: return "Watering"
        }
    }

    /// One round of care, for "3 more turns to Rich Soil".
    func careCountNoun(_ count: Int) -> String {
        let singular: String
        switch self {
        case .compostBin: singular = "turn"
        case .butterfly: singular = "feeding"
        case .rainBarrel: singular = "fill"
        default: singular = "watering"
        }
        return count == 1 ? singular : singular + "s"
    }

    /// SF Symbol shown on the care button and the "needs care" badge.
    var careIcon: String {
        switch self {
        case .compostBin: return "arrow.triangle.2.circlepath"
        case .butterfly: return "camera.macro"
        default: return "drop.fill"
        }
    }
}

struct GardenItem: Identifiable, Codable {
    var id: UUID
    var kind: GardenItemKind
    var name: String
    var cost: Int
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
    // IDs are fixed (not UUID()) because PlacedItem.itemID is persisted and has to
    // still match these after the app relaunches.
    static let shopItems: [GardenItem] = [
        GardenItem(id: UUID(uuidString: "E0C06A2D-0000-4000-8000-000000000001")!, kind: .seedling, name: "Seedling", cost: 10, tintColor: "green"),
        GardenItem(id: UUID(uuidString: "E0C06A2D-0000-4000-8000-000000000002")!, kind: .flower, name: "Flower", cost: 25, tintColor: "yellow"),
        GardenItem(id: UUID(uuidString: "E0C06A2D-0000-4000-8000-000000000003")!, kind: .tree, name: "Tree", cost: 50, tintColor: "green"),
        GardenItem(id: UUID(uuidString: "E0C06A2D-0000-4000-8000-000000000004")!, kind: .compostBin, name: "Compost Bin", cost: 40, tintColor: "brown"),
        GardenItem(id: UUID(uuidString: "E0C06A2D-0000-4000-8000-000000000005")!, kind: .rainBarrel, name: "Rain Barrel", cost: 45, tintColor: "blue"),
        GardenItem(id: UUID(uuidString: "E0C06A2D-0000-4000-8000-000000000006")!, kind: .butterfly, name: "Butterfly", cost: 30, tintColor: "yellow")
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

    /// Waterings still needed to reach the next stage, or nil once fully grown.
    var careUntilNextStage: Int? {
        switch careCount {
        case ..<1: return 1
        case 1...2: return 3 - careCount
        case 3...5: return 6 - careCount
        default: return nil
        }
    }
}

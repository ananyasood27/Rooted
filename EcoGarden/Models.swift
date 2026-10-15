import Foundation
import SwiftUI

// MARK: - Sustainability Task

/// Which habit a task is — stable across launches, so impact can be tallied per habit.
enum EcoTaskKind: String, Codable, CaseIterable {
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
    var volunteerHours: Double = 0
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

// MARK: - Volunteering

/// The five kinds of volunteering the app tracks. Each one builds a different place on
/// the street behind your garden.
enum VolunteerCategory: String, Codable, CaseIterable, Identifiable {
    case animals, library, nature, food, homes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .animals: return "Animals"
        case .library: return "Library"
        case .nature: return "Nature"
        case .food: return "Food"
        case .homes: return "Homes"
        }
    }

    /// The place this kind of volunteering builds.
    var buildingName: String {
        switch self {
        case .animals: return "Animal Shelter"
        case .library: return "Library"
        case .nature: return "Nature Center"
        case .food: return "Food Bank"
        case .homes: return "Neighborhood"
        }
    }

    var icon: String {
        switch self {
        case .animals: return "pawprint.fill"
        case .library: return "books.vertical.fill"
        case .nature: return "bird.fill"
        case .food: return "basket.fill"
        case .homes: return "house.fill"
        }
    }

    var color: Color {
        switch self {
        case .animals: return Color(red: 0.72, green: 0.30, blue: 0.25)
        case .library: return Color(red: 0.62, green: 0.40, blue: 0.32)
        case .nature: return Theme.leaf
        case .food: return Color(red: 0.40, green: 0.52, blue: 0.66)
        case .homes: return Color(red: 0.85, green: 0.62, blue: 0.28)
        }
    }

    /// Every place goes through the same four steps.
    static let stageNames = ["Empty Lot", "Under Construction", "Open", "Thriving"]
    /// Total volunteer hours needed to reach each level.
    static let hourThresholds: [Double] = [0, 1, 4, 10]
    /// A place stays lively for this many days after you last volunteered for it.
    static let livelyDays: Double = 14

    static func level(forHours hours: Double) -> Int {
        hourThresholds.lastIndex(where: { hours >= $0 }) ?? 0
    }

    /// Hours still needed to reach the next level, or nil once it's fully built.
    static func hoursToNextLevel(from hours: Double) -> Double? {
        let next = level(forHours: hours) + 1
        guard next < hourThresholds.count else { return nil }
        return hourThresholds[next] - hours
    }
}

/// A real place to volunteer.
struct Opportunity: Identifiable {
    let id: String
    let category: VolunteerCategory
    let organization: String
    let title: String
    let details: String
    let location: String
    let ageNote: String
    let url: String
}

// Taken from the City of Baytown volunteer pages, Houston Food Bank and Baytown Habitat for
// Humanity (checked October 2026). Programs open, close and change their rules — re-check
// every link before submitting.
extension Opportunity {
    private static let parksPage = "https://baytown.org/1409/Wetlands-Nature-Center-and-Park-Voluntee"

    static let baytown: [Opportunity] = [
        Opportunity(
            id: "shelter", category: .animals, organization: "Baytown Animal Shelter", title: "Shelter volunteer",
            details: "Scheduled shifts at the shelter, adoption events, and group \"shelter takeovers.\"",
            location: "705 N Robert C. Lanier Dr, Baytown", ageNote: "Age rules are on the sign-up form",
            url: "https://baytown.org/1376/Volunteer-Opportunities"),
        Opportunity(
            id: "doggie-dates", category: .animals, organization: "Baytown Animal Services", title: "Doggie Dates",
            details: "Take a shelter dog out for the day on a Tuesday, Thursday or Saturday, then send the shelter a report card and photos.",
            location: "705 N Robert C. Lanier Dr, Baytown", ageNote: "The person signing up must be 18+; teens can come along",
            url: "https://baytown.org/1425/Doggie-Dates"),
        Opportunity(
            id: "library-teens", category: .library, organization: "Sterling Municipal Library", title: "Teen volunteer",
            details: "Create displays, prepare take-home and program crafts, and help set up for library events.",
            location: "1 Mary Elizabeth Wilbanks Ave, Baytown", ageNote: "For teens",
            url: "https://www.baytown.org/305/Teen-Volunteering"),
        Opportunity(
            id: "epic-teens", category: .nature, organization: "Eddie V. Gray Wetlands Center", title: "E.P.I.C. Teen Volunteers",
            details: "A free service-learning club that tackles coastal environmental problems with hands-on projects. Meets Wednesdays 4–5 PM — no registration needed.",
            location: "1724 Market St, Baytown", ageNote: "High school students",
            url: parksPage),
        Opportunity(
            id: "bird-buddies", category: .nature, organization: "Baytown Nature Center", title: "Bird Buddies",
            details: "Keep the bird feeders in the Baytown Nature Center filled.",
            location: "6213 Bayway Dr, Baytown", ageNote: "Check the sign-up page",
            url: parksPage),
        Opportunity(
            id: "park-projects", category: .nature, organization: "Baytown Parks & Recreation", title: "Park projects for groups",
            details: "Coastline cleanups, painting and building projects, bird blinds, garden beds and litter pickups — good for a club or class.",
            location: "Baytown Nature Center and city parks", ageNote: "Groups — contact the Parks team through the page",
            url: parksPage),
        Opportunity(
            id: "food-bank", category: .food, organization: "Houston Food Bank", title: "Warehouse shift",
            details: "Sort and pack food at the Houston Food Bank's warehouse. Sign up for a shift online.",
            location: "535 Portwall St, Houston", ageNote: "Kids 6+ can help with an adult; check the current age rules",
            url: "https://www.houstonfoodbank.org/volunteer/"),
        Opportunity(
            id: "habitat", category: .homes, organization: "Baytown Habitat for Humanity", title: "Build volunteer",
            details: "Help at Habitat construction sites or with office projects.",
            location: "3900 N Main St, Baytown", ageNote: "Check age rules on the sign-up page",
            url: "https://baytownhabitat.org/volunteer/")
    ]
}

/// One logged stretch of volunteering.
struct VolunteerEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var category: VolunteerCategory
    var organization: String
    var opportunityID: String? = nil
    var hours: Double
    var date: Date
    var proofFileName: String? = nil
}

/// "3" for whole hours, "2.5" otherwise.
func formatHours(_ hours: Double) -> String {
    hours == hours.rounded() ? String(format: "%.0f", hours) : String(format: "%.1f", hours)
}

// MARK: - Map places

/// A real spot on the community map: somewhere to volunteer, or one of the drop-off
/// sites from the task tips.
struct CommunityPlace: Identifiable {
    enum Kind: Equatable {
        case volunteer(VolunteerCategory)
        case dropOff
    }

    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let kind: Kind
    /// One line on what you can do there.
    let whatsHere: String
    /// Opportunities (from Opportunity.baytown) you can log hours for at this place.
    var opportunityIDs: [String] = []
    let url: String
}

// Addresses from the City of Baytown, Goodwill Houston, Houston Food Bank and Baytown
// Habitat websites. Coordinates were looked up from those addresses with Apple Maps and
// OpenStreetMap (October 2026) and saved here, so the map works without a connection.
extension CommunityPlace {
    static let baytown: [CommunityPlace] = [
        CommunityPlace(
            id: "animal-shelter", name: "Baytown Animal Shelter", address: "705 N Robert C. Lanier Dr, Baytown",
            latitude: 29.75051, longitude: -94.98262, kind: .volunteer(.animals),
            whatsHere: "Shelter shifts, adoption events, and Doggie Dates",
            opportunityIDs: ["shelter", "doggie-dates"], url: "https://baytown.org/1209/Animal-Services"),
        CommunityPlace(
            id: "library", name: "Sterling Municipal Library", address: "1 Mary Elizabeth Wilbanks Ave, Baytown",
            latitude: 29.73670, longitude: -94.97985, kind: .volunteer(.library),
            whatsHere: "Teen volunteers make displays and crafts and help set up events",
            opportunityIDs: ["library-teens"], url: "https://www.baytown.org/305/Teen-Volunteering"),
        CommunityPlace(
            id: "wetlands-center", name: "Eddie V. Gray Wetlands Center", address: "1724 Market St, Baytown",
            latitude: 29.73197, longitude: -94.98523, kind: .volunteer(.nature),
            whatsHere: "E.P.I.C. Teen Volunteers meet here Wednesdays 4–5 PM",
            opportunityIDs: ["epic-teens"], url: "https://baytown.org/1409/Wetlands-Nature-Center-and-Park-Voluntee"),
        CommunityPlace(
            id: "nature-center", name: "Baytown Nature Center", address: "6213 Bayway Dr, Baytown",
            latitude: 29.75510, longitude: -95.03679, kind: .volunteer(.nature),
            whatsHere: "Bird Buddies and group park projects",
            opportunityIDs: ["bird-buddies", "park-projects"], url: "https://baytown.org/1409/Wetlands-Nature-Center-and-Park-Voluntee"),
        CommunityPlace(
            id: "food-bank", name: "Houston Food Bank", address: "535 Portwall St, Houston",
            latitude: 29.78097, longitude: -95.27474, kind: .volunteer(.food),
            whatsHere: "Warehouse shifts sorting and packing food",
            opportunityIDs: ["food-bank"], url: "https://www.houstonfoodbank.org/volunteer/"),
        CommunityPlace(
            id: "habitat", name: "Baytown Habitat for Humanity", address: "3900 N Main St, Baytown",
            latitude: 29.76338, longitude: -94.96390, kind: .volunteer(.homes),
            whatsHere: "Build days and office projects",
            opportunityIDs: ["habitat"], url: "https://baytownhabitat.org/volunteer/"),
        CommunityPlace(
            id: "green-center", name: "Baytown Green Center", address: "1601 W Main St, Baytown",
            latitude: 29.72158, longitude: -94.98676, kind: .dropOff,
            whatsHere: "Recycling, electronics, textiles and yard waste (Baytown residents)",
            url: "https://baytown.org/1227"),
        CommunityPlace(
            id: "goodwill", name: "Goodwill Donation Center", address: "3501 Garth Rd Suite 100, Baytown",
            latitude: 29.76066, longitude: -94.97744, kind: .dropOff,
            whatsHere: "Donate clothes, books and household items",
            url: "https://www.goodwillhouston.org/locations/baytown")
    ]
}

// MARK: - Green upgrades (eco habits change the street)

/// Volunteering builds the places on the street; eco habits make the street around them
/// greener. Each habit adds a fixture after 3 completions and upgrades it after 10.
extension EcoTaskKind {
    static let upgradeThresholds = [3, 10]

    /// What the habit adds to the street at tier 1 and tier 2.
    var upgradeNames: [String] {
        switch self {
        case .travel: return ["Bike Rack", "Bike Lane"]
        case .recycle: return ["Recycling Bins", "Recycling Station"]
        case .compost: return ["Garden Bed", "Community Garden"]
        case .water: return ["Rain Barrel", "Rain Garden"]
        case .reusable: return ["Water Refill Station", "Reusable Market"]
        case .donate: return ["Donation Box", "Little Free Library"]
        }
    }

    /// How the habit is counted, for "3 walk or bike trips".
    var habitPhrase: String {
        switch self {
        case .travel: return "walk or bike trips"
        case .recycle: return "times recycling"
        case .compost: return "times composting"
        case .water: return "water-saving days"
        case .reusable: return "reusable bag or bottle days"
        case .donate: return "donations"
        }
    }

    /// 0 = nothing yet, 1 = first fixture, 2 = upgraded.
    func upgradeTier(forCount count: Int) -> Int {
        Self.upgradeThresholds.filter { count >= $0 }.count
    }
}

// MARK: - Community level

/// One level for the whole community, filled by eco tasks and volunteering together.
enum CommunityLevel {
    static let pointsPerTask = 1
    static let pointsPerVolunteerHour = 3

    static let names = ["Quiet Street", "Growing Block", "Green Neighborhood", "Thriving Community", "Model Community"]
    static let thresholds = [0, 10, 30, 60, 100]
    /// What reaching each level adds to the street (nothing for the first).
    static let unlocks = ["", "Street trees", "Streetlights", "Bunting flags", "Festival lights and balloons"]

    /// 0-based level for a points total.
    static func level(forPoints points: Int) -> Int {
        thresholds.lastIndex(where: { points >= $0 }) ?? 0
    }

    /// How far through the current level, 0...1 (1 at the top level).
    static func progress(forPoints points: Int) -> Double {
        let level = level(forPoints: points)
        guard level + 1 < thresholds.count else { return 1 }
        return Double(points - thresholds[level]) / Double(thresholds[level + 1] - thresholds[level])
    }

    static func pointsToNextLevel(from points: Int) -> Int? {
        let next = level(forPoints: points) + 1
        guard next < thresholds.count else { return nil }
        return thresholds[next] - points
    }
}

// MARK: - Weekly challenge

/// A goal each week that needs both kinds of doing good. Rotates so it isn't the same every week.
struct WeeklyChallenge {
    let ecoGoal: Int
    let hoursGoal: Double

    static let rewardCoins = 50
    static let rewardPoints = 10
    private static let rotation: [(Int, Double)] = [(3, 1), (5, 1), (4, 2)]

    static func forWeek(of date: Date) -> WeeklyChallenge {
        let week = Calendar.current.component(.weekOfYear, from: date)
        let goal = rotation[week % rotation.count]
        return WeeklyChallenge(ecoGoal: goal.0, hoursGoal: goal.1)
    }

    /// Identifies a week, e.g. "2026-42", so the reward is only paid once.
    static func weekKey(for date: Date) -> String {
        let cal = Calendar.current
        return "\(cal.component(.yearForWeekOfYear, from: date))-\(cal.component(.weekOfYear, from: date))"
    }
}

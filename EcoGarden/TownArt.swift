import SwiftUI

// Drawn art for the five community places on the street behind the garden.
// Each place has four levels (empty lot, under construction, open, thriving), and once
// it's open it looks different depending on whether you've volunteered recently:
// lively places have lit windows, people and flowers; quiet ones get a CLOSED sign and weeds.
//
// Uses the same painter as the plants (PlantPainter in PlantArt.swift), so the units work
// the same way: x runs -80...80 around the middle of the lot, y runs up from the sidewalk.

struct BuildingSprite: View {
    let category: VolunteerCategory
    let level: Int
    var lively = true
    var isNight = false
    /// Width of the frame in points.
    var size: CGFloat = 170

    static let designSize = CGSize(width: 160, height: 130)
    /// Design units between the bottom of the frame and the sidewalk.
    static let groundInset: CGFloat = 8

    var body: some View {
        Canvas { ctx, canvasSize in
            let unit = canvasSize.width / Self.designSize.width
            let painter = PlantPainter(
                ctx: ctx,
                u: unit,
                origin: CGPoint(x: canvasSize.width / 2, y: canvasSize.height - Self.groundInset * unit),
                wilt: 0,
                bends: false
            )
            painter.drawBuilding(category, level: level, lively: lively, isNight: isNight)
        }
        .frame(width: size, height: size * Self.designSize.height / Self.designSize.width)
        // Quiet places look a bit washed out, like plants that need water.
        .saturation(lively || level < 2 ? 1 : 0.6)
        .accessibilityHidden(true)
    }
}

/// Whether a place is in use, and whether it's dark out — decides how windows look.
private struct Look {
    let lively: Bool
    let isNight: Bool
}

/// Where a finished building's door is and where its visitors stand.
private struct Layout {
    var doorX: CGFloat
    var doorY: CGFloat
    var peopleXs: [CGFloat]
    var planterXs: [CGFloat]
    /// What the sign on the door says when it's quiet (nil = no sign, e.g. houses).
    var closedText: String? = "CLOSED"
}

extension PlantPainter {
    func drawBuilding(_ category: VolunteerCategory, level: Int, lively: Bool, isNight: Bool) {
        let look = Look(lively: lively, isNight: isNight)
        oval(0, 0, 76, 6, Color(red: 0.44, green: 0.62, blue: 0.36))

        switch level {
        case 0:
            emptyLot(category)
        case 1:
            construction(category, look: look)
        default:
            let big = level >= 3
            let layout: Layout
            switch category {
            case .animals: layout = shelter(big: big, look: look)
            case .library: layout = library(big: big, look: look)
            case .nature: layout = natureCenter(big: big, look: look)
            case .food: layout = foodBank(big: big, look: look)
            case .homes: layout = neighborhood(big: big, look: look)
            }
            if lively {
                for x in layout.planterXs { planter(x) }
                for (i, x) in layout.peopleXs.enumerated() { person(x, variant: i) }
            } else {
                quietDetails(layout)
            }
        }
    }

    // MARK: Small pieces

    func label(_ text: String, _ x: CGFloat, _ y: CGFloat, size: CGFloat, _ color: Color) {
        ctx.draw(Text(text).font(.system(size: size * u, weight: .heavy, design: .rounded)).foregroundColor(color), at: pt(x, y))
    }

    func symbol(_ name: String, _ x: CGFloat, _ y: CGFloat, size: CGFloat, _ color: Color) {
        ctx.draw(Text(Image(systemName: name)).font(.system(size: size * u, weight: .bold)).foregroundColor(color), at: pt(x, y))
    }

    private func window(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ look: Look) {
        if look.lively && look.isNight {
            oval(x + w / 2, y + h / 2, w * 0.95, h * 0.95, Color(red: 1, green: 0.85, blue: 0.45).opacity(0.35))
        }
        rect(x - 0.8, y - 0.8, w + 1.6, h + 1.6, Color(white: 0.96))
        let pane: Color
        if !look.lively {
            pane = Color(red: 0.28, green: 0.30, blue: 0.34)
        } else if look.isNight {
            pane = Color(red: 1, green: 0.86, blue: 0.48)
        } else {
            pane = Color(red: 0.74, green: 0.86, blue: 0.95)
        }
        rect(x, y, w, h, pane)
        rect(x + w / 2 - 0.3, y, 0.6, h, Color(white: 0.96))
    }

    private func person(_ x: CGFloat, variant: Int) {
        let shirts = [Theme.water, Theme.petal, Theme.sunflower, Theme.leaf, Theme.lilac]
        let skins = [Color(red: 0.96, green: 0.80, blue: 0.66), Color(red: 0.78, green: 0.57, blue: 0.42), Color(red: 0.52, green: 0.36, blue: 0.26)]
        rect(x - 1.8, 0, 1.4, 4, Color(red: 0.25, green: 0.27, blue: 0.35))
        rect(x + 0.4, 0, 1.4, 4, Color(red: 0.25, green: 0.27, blue: 0.35))
        rect(x - 2.6, 3.5, 5.2, 6.5, radius: 2, shirts[variant % shirts.count])
        dot(x, 12.4, 2.3, skins[variant % skins.count])
    }

    private func planter(_ x: CGFloat) {
        dot(x - 3, 4.2, 1.7, Theme.petal)
        dot(x, 4.8, 1.7, Theme.sunflower)
        dot(x + 3, 4.2, 1.7, Theme.lilac)
        rect(x - 5.5, 0, 11, 3.2, radius: 0.8, Theme.woodDark)
    }

    private func weeds(_ x: CGFloat) {
        leaf(x, 0, angle: -22, length: 8, width: 3, Theme.wilt, droops: false)
        leaf(x + 1, 0, angle: 18, length: 7, width: 3, Theme.leafDark, droops: false)
    }

    private func quietDetails(_ layout: Layout) {
        for x in [-38, -14, 24, 44] as [CGFloat] { weeds(x) }
        if let text = layout.closedText {
            rect(layout.doorX - 8, layout.doorY, 16, 5.5, radius: 1, Color(red: 0.75, green: 0.22, blue: 0.20))
            label(text, layout.doorX, layout.doorY + 2.75, size: 3.4, .white)
        }
    }

    private func gableRoof(_ x0: CGFloat, _ x1: CGFloat, base: CGFloat, peak: CGFloat, _ color: Color) {
        poly([(x0, base), (x1, base), ((x0 + x1) / 2, peak)], color)
    }

    // MARK: Level 1 and 2 — before it's built

    private func emptyLot(_ category: VolunteerCategory) {
        oval(-6, 1, 50, 4.5, Theme.soil.opacity(0.45))
        // survey stakes marking out where the building will go
        for x in [-42, 30] as [CGFloat] {
            rect(x - 0.8, 0, 1.6, 9, Theme.wood)
        }
        stem(-42, 8, 30, 8, width: 0.5, .white.opacity(0.85))
        for x in [-24, 8, 52] as [CGFloat] { weeds(x) }

        // "coming soon" sign showing what this lot is for
        rect(47, 0, 2.4, 22, Theme.woodDark)
        rect(34, 15, 28, 18, radius: 1.5, Theme.card)
        symbol(category.icon, 48, 26.5, size: 7.5, category.color)
        label("COMING SOON", 48, 18.6, size: 3.2, Theme.bark)
    }

    private func construction(_ category: VolunteerCategory, look: Look) {
        let grey = Color(white: 0.56)
        rect(-46, 0, 92, 4, Color(white: 0.74))
        rect(-42, 4, 84, 16, category.color.mix(with: .white, by: 0.2))
        rect(-42, 18, 84, 2, category.color.mix(with: .black, by: 0.15))

        // scaffolding
        for x in [-46, -16, 16, 46] as [CGFloat] {
            rect(x - 1, 0, 2, 44, grey)
        }
        stem(-46, 4, -16, 22, width: 0.8, grey)
        stem(16, 22, 46, 40, width: 0.8, grey)
        for y in [22, 40] as [CGFloat] {
            rect(-48, y, 96, 2.2, Theme.wood)
        }

        // crane
        let yellow = Theme.sunflower
        rect(56, 0, 4, 72, yellow)
        rect(18, 70, 52, 3, yellow)
        stem(28, 70, 28, 53, width: 0.6, Theme.bark)
        rect(20, 50, 16, 3, grey)

        // traffic cones
        for x in [-58, -51] as [CGFloat] {
            poly([(x - 3, 0), (x + 3, 0), (x, 8)], Color(red: 0.95, green: 0.50, blue: 0.15))
            rect(x - 1.6, 3, 3.2, 1.2, .white)
        }

        if look.lively {
            // workers in hard hats
            for (i, x) in ([-28, 6] as [CGFloat]).enumerated() {
                person(x, variant: i + 1)
                oval(x, 13.6, 2.7, 1.4, yellow)
            }
        } else {
            for x in [-36, 0, 30] as [CGFloat] { weeds(x) }
        }
    }

    // MARK: Level 3 and 4 — finished places

    private func shelter(big: Bool, look: Look) -> Layout {
        let red = Color(red: 0.72, green: 0.30, blue: 0.25)
        let roof = Color(red: 0.40, green: 0.22, blue: 0.18)

        if big {
            // fenced play yard, plus a new wing for more animals
            for x in stride(from: -76, through: -48, by: 7) {
                rect(CGFloat(x), 0, 1.3, 10, .white)
            }
            stem(-76, 4, -47, 4, width: 0.8, .white)
            stem(-76, 8.5, -47, 8.5, width: 0.8, .white)
            if look.lively {
                dog(-68, Color(red: 0.55, green: 0.38, blue: 0.24))
                dog(-56, Color(red: 0.92, green: 0.84, blue: 0.68))
            }
            rect(40, 0, 28, 28, red.mix(with: .black, by: 0.1))
            gableRoof(37, 71, base: 28, peak: 39, roof)
            window(48, 12, 10, 9, look)
        }

        rect(-40, 0, 80, 42, red)
        rect(-40, 40, 80, 2, .white)
        gableRoof(-46, 46, base: 42, peak: 66, roof)
        stem(-46, 42, 0, 66, width: 1.2, .white)
        stem(0, 66, 46, 42, width: 1.2, .white)

        // barn door
        rect(-9, 0, 18, 26, .white)
        rect(-7.5, 0, 15, 24.5, red.mix(with: .black, by: 0.15))
        stem(-7.5, 0, 7.5, 24.5, width: 0.8, .white)
        stem(-7.5, 24.5, 7.5, 0, width: 0.8, .white)

        window(-32, 16, 12, 12, look)
        window(20, 16, 12, 12, look)
        dot(0, 52, 7, .white)
        symbol("pawprint.fill", 0, 52, size: 8, red)

        return Layout(doorX: 0, doorY: 12, peopleXs: big ? [-20, 15, 30] : [-20, 16], planterXs: [-28, 28])
    }

    private func dog(_ x: CGFloat, _ color: Color) {
        oval(x, 4, 4.6, 2.6, color)
        dot(x + 4.6, 6, 2.3, color)
        stem(x - 4.4, 4.5, x - 6.5, 7.5, width: 1, color)
        rect(x - 3, 0, 1.2, 3, color)
        rect(x + 2, 0, 1.2, 3, color)
    }

    private func library(big: Bool, look: Look) -> Layout {
        let brick = Color(red: 0.72, green: 0.46, blue: 0.36)
        let stone = Color(red: 0.93, green: 0.89, blue: 0.80)

        if big {
            // side wings and a reading bench out front
            for x in [-70, 46] as [CGFloat] {
                rect(x, 0, 24, 32, brick.mix(with: .black, by: 0.06))
                rect(x - 1, 31, 26, 2.4, stone)
                window(x + 7, 12, 10, 12, look)
            }
            rect(52, 4, 16, 1.6, Theme.wood)
            rect(53, 0, 1.4, 4, Theme.woodDark)
            rect(65.6, 0, 1.4, 4, Theme.woodDark)
        }

        rect(-44, 0, 88, 46, brick)
        rect(-46, 0, 92, 5, stone)
        rect(-46, 44, 92, 3, stone)
        gableRoof(-48, 48, base: 47, peak: 64, stone)
        symbol("books.vertical.fill", 0, 53.5, size: 8, brick.mix(with: .black, by: 0.2))
        for x in [-30, -18, 14, 26] as [CGFloat] {
            rect(x, 5, 4, 39, stone)
        }
        rect(-7, 5, 14, 22, Color(red: 0.36, green: 0.25, blue: 0.20))
        dot(0, 27, 7, Color(red: 0.36, green: 0.25, blue: 0.20))
        window(-42, 18, 8, 14, look)
        window(34, 18, 8, 14, look)

        return Layout(doorX: 0, doorY: 14, peopleXs: big ? [-24, 18, 59] : [-24, 20], planterXs: [-38, 38])
    }

    private func natureCenter(big: Bool, look: Look) -> Layout {
        let roofGreen = Color(red: 0.33, green: 0.50, blue: 0.34)

        if big {
            // pond with a boardwalk, a wading bird, and trees
            oval(-56, 2, 22, 5, Theme.water)
            oval(-60, 2.5, 8, 1.2, .white.opacity(0.5))
            rect(-76, 3.2, 40, 2, Theme.wood)
            for x in [-72, -60, -48] as [CGFloat] {
                rect(x, 0, 1.2, 3.2, Theme.woodDark)
            }
            symbol("bird.fill", -54, 14, size: 9, .white.opacity(0.95))
            rect(60, 0, 3, 22, Theme.trunk)
            blobs([(61, 28, 12), (68, 36, 8)], Theme.leafDark)
            blobs([(57, 32, 8)], Theme.leaf)
        }

        blobs([(-46, 5, 6), (44, 5, 6)], Theme.leaf)
        rect(-42, 0, 84, 4, Theme.wood)
        for x in [-38, -14, 10, 34] as [CGFloat] {
            rect(x, 4, 4, 28, Theme.woodDark)
        }
        stem(-38, 13, 38, 13, width: 1, Theme.woodDark)
        poly([(-50, 32), (50, 32), (34, 48), (-34, 48)], roofGreen)
        rect(-50, 31, 100, 2.4, roofGreen.mix(with: .black, by: 0.2))
        rect(-13, 36, 26, 9, radius: 1.5, Theme.card)
        symbol("bird.fill", 0, 40.5, size: 6, roofGreen)

        return Layout(doorX: -26, doorY: 18, peopleXs: big ? [-24, -2, 22, 36] : [-22, 4, 22], planterXs: [], closedText: "CLOSED")
    }

    private func foodBank(big: Bool, look: Look) -> Layout {
        let steel = Color(red: 0.60, green: 0.67, blue: 0.74)
        let steelDark = Color(red: 0.40, green: 0.46, blue: 0.52)
        let half: CGFloat = big ? 60 : 44

        rect(-half, 0, half * 2, 40, steel)
        rect(-half - 2, 40, half * 2 + 4, 4, steelDark)
        rect(-half, 30, half * 2, 2, Theme.leaf)

        let doors: [CGFloat] = big ? [-36, 4] : [-12]
        for dx in doors {
            rect(dx, 0, 24, 24, steelDark)
            for i in 1...5 {
                stem(dx, CGFloat(i) * 4, dx + 24, CGFloat(i) * 4, width: 0.5, steel)
            }
        }
        window(-half + 5, 16, 9, 8, look)
        window(half - 14, 16, 9, 8, look)

        // sign on the roof
        rect(-18, 44, 36, 11, radius: 1.5, Theme.card)
        symbol("basket.fill", -9, 49.5, size: 6, Theme.leaf)
        label("FOOD", 6, 49.5, size: 4.4, Theme.leafDark)

        // crates waiting to go out
        for (x, y) in [(-half + 2, 0), (-half + 12, 0), (-half + 7, 7)] as [(CGFloat, CGFloat)] {
            rect(x, y, 9, 7, Theme.wood)
            stem(x, y + 3.5, x + 9, y + 3.5, width: 0.5, Theme.woodDark)
        }

        if big {
            // delivery van
            rect(44, 3, 24, 15, radius: 2, .white)
            rect(66, 3, 11, 11, radius: 2, .white)
            rect(68.5, 8.5, 6, 4, Color(red: 0.74, green: 0.86, blue: 0.95))
            rect(44, 8, 24, 2.5, Theme.leaf)
            dot(50, 3, 3, Theme.bark)
            dot(71, 3, 3, Theme.bark)
        }

        let door = doors[0] + 12
        return Layout(doorX: door, doorY: 12, peopleXs: big ? [-14, 30, 38] : [-22, 20], planterXs: [])
    }

    private func neighborhood(big: Bool, look: Look) -> Layout {
        if big {
            house(-50, Color(red: 0.62, green: 0.74, blue: 0.86), Color(red: 0.36, green: 0.38, blue: 0.46), look)
            house(50, Color(red: 0.72, green: 0.81, blue: 0.64), Color(red: 0.45, green: 0.30, blue: 0.22), look)
            house(0, Color(red: 0.96, green: 0.87, blue: 0.62), Color(red: 0.56, green: 0.27, blue: 0.22), look)
        } else {
            rect(30, 0, 3, 16, Theme.trunk)
            blobs([(31.5, 22, 9)], Theme.leaf)
            house(0, Color(red: 0.96, green: 0.87, blue: 0.62), Color(red: 0.56, green: 0.27, blue: 0.22), look)
        }
        return Layout(doorX: 0, doorY: 0, peopleXs: big ? [-30, 22, 70] : [-24, 20], planterXs: big ? [-62, 38] : [-12], closedText: nil)
    }

    private func house(_ x: CGFloat, _ body: Color, _ roof: Color, _ look: Look) {
        rect(x + 7, 30, 4, 12, roof.mix(with: .black, by: 0.2))
        rect(x - 16, 0, 32, 28, body)
        gableRoof(x - 20, x + 20, base: 28, peak: 44, roof)
        rect(x - 4, 0, 8, 14, Color(red: 0.42, green: 0.30, blue: 0.22))
        window(x - 13, 12, 7, 7, look)
        window(x + 6, 12, 7, 7, look)
    }
}

#Preview("All places") {
    ScrollView {
        VStack(spacing: 4) {
            ForEach(VolunteerCategory.allCases) { category in
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { level in
                        BuildingSprite(category: category, level: level, size: 96)
                    }
                    BuildingSprite(category: category, level: 3, lively: false, size: 96)
                }
            }
        }
    }
    .background(Color(red: 0.55, green: 0.74, blue: 0.42))
}

// MARK: - Street upgrades from eco habits

/// The small things eco habits add to the street (bike racks, recycling bins, garden beds…).
/// Same painter and units as the buildings, in a 60 × 60 box.
struct UpgradeSprite: View {
    let kind: EcoTaskKind
    let tier: Int
    var size: CGFloat = 52

    static let designSize = CGSize(width: 60, height: 60)
    static let groundInset: CGFloat = 4

    var body: some View {
        Canvas { ctx, canvasSize in
            let unit = canvasSize.width / Self.designSize.width
            let painter = PlantPainter(
                ctx: ctx,
                u: unit,
                origin: CGPoint(x: canvasSize.width / 2, y: canvasSize.height - Self.groundInset * unit),
                wilt: 0,
                bends: false
            )
            painter.drawUpgrade(kind, big: tier >= 2)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension PlantPainter {
    func drawUpgrade(_ kind: EcoTaskKind, big: Bool) {
        switch kind {
        case .travel: bikeRack(big)
        case .recycle: recyclingBins(big)
        case .compost: gardenBeds(big)
        case .water: rainCatcher(big)
        case .reusable: refillOrMarket(big)
        case .donate: donationBox(big)
        }
    }

    private func ring(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, width: CGFloat, _ color: Color) {
        let c = pt(x, y)
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r * u, y: c.y - r * u, width: r * 2 * u, height: r * 2 * u)),
                   with: .color(color), lineWidth: width * u)
    }

    private func bike(_ x: CGFloat, _ color: Color) {
        ring(x - 6, 5, 4.6, width: 1.3, Theme.bark)
        ring(x + 6, 5, 4.6, width: 1.3, Theme.bark)
        stem(x - 6, 5, x, 10, width: 1.4, color)
        stem(x, 10, x + 6, 5, width: 1.4, color)
        stem(x - 1, 10, x + 4, 10, width: 1.4, color)
        stem(x, 10, x - 1, 13, width: 1.2, color)
        rect(x - 3, 13, 4, 1.4, radius: 0.6, Theme.bark)
        stem(x + 4, 10, x + 5, 14, width: 1.2, color)
    }

    private func bikeRack(_ big: Bool) {
        let steel = Color(white: 0.55)
        let hoops: [CGFloat] = big ? [-20, -4, 12] : [-12, 4]
        for x in hoops {
            var p = Path()
            p.move(to: pt(x - 5, 0))
            p.addQuadCurve(to: pt(x + 5, 0), control: pt(x, 24))
            ctx.stroke(p, with: .color(steel), style: StrokeStyle(lineWidth: 2 * u, lineCap: .round))
        }
        bike(-8, Theme.water)
        if big { bike(14, Theme.petal) }
    }

    private func bin(_ x: CGFloat, _ color: Color) {
        rect(x - 6, 0, 12, 16, radius: 1.5, color)
        rect(x - 7, 15.5, 14, 2.6, radius: 1, color.mix(with: .black, by: 0.2))
        symbol("arrow.3.trianglepath", x, 8, size: 6, .white)
    }

    private func recyclingBins(_ big: Bool) {
        if big {
            rect(-26, 0, 1.6, 26, Theme.woodDark)
            rect(24.4, 0, 1.6, 26, Theme.woodDark)
            poly([(-29, 26), (29, 26), (25, 32), (-25, 32)], Theme.leafDark)
            bin(-14, Theme.water)
            bin(0, Theme.leaf)
            bin(14, Theme.sunflower)
        } else {
            bin(-7, Theme.water)
            bin(7, Theme.leaf)
        }
    }

    private func bed(_ x: CGFloat, width: CGFloat, sprouts: Int) {
        rect(x - width / 2, 0, width, 7, radius: 1, Theme.wood)
        rect(x - width / 2 + 1.5, 5.5, width - 3, 2, Theme.soil)
        for i in 0..<sprouts {
            let sx = x - width / 2 + width * (CGFloat(i) + 0.5) / CGFloat(sprouts)
            stem(sx, 7, sx, 12, width: 1, Theme.leaf)
            leaf(sx, 12, angle: -40, length: 5, width: 3, Theme.leafLight, droops: false)
            leaf(sx, 12, angle: 40, length: 5, width: 3, Theme.leaf, droops: false)
        }
    }

    private func gardenBeds(_ big: Bool) {
        if big {
            for x in [-20, -8] as [CGFloat] {
                stem(x, 7, x, 26, width: 1.2, Theme.leaf)
                leaf(x, 15, angle: -50, length: 6, width: 3.5, Theme.leaf, droops: false)
                bloom(x, 27, r: 4.5, Theme.sunflower)
            }
            bed(-12, width: 32, sprouts: 3)
            rect(13, 0, 14, 15, Theme.woodDark)
            for y in [4, 8, 12] as [CGFloat] {
                stem(13, y, 27, y, width: 0.6, Theme.wood)
            }
            oval(20, 15, 6, 2, Theme.compost)
        } else {
            bed(0, width: 36, sprouts: 4)
        }
    }

    private func rainCatcher(_ big: Bool) {
        if big {
            oval(0, 1.5, 26, 4, Theme.water.opacity(0.75))
            for (x, y) in [(-22, 1), (-14, 3.5), (12, 3.2), (21, 1.2)] as [(CGFloat, CGFloat)] {
                dot(x, y, 1.8, Color(white: 0.62))
            }
            for x in [-26, 24] as [CGFloat] {
                leaf(x, 0, angle: -20, length: 10, width: 4, Theme.leaf, droops: false)
                leaf(x + 1, 0, angle: 20, length: 9, width: 4, Theme.leafDark, droops: false)
            }
            bloom(-18, 9, r: 3.5, Theme.lilac)
            bloom(17, 10, r: 3.5, Theme.petal)
            rect(-1, 0, 1.4, 14, Theme.woodDark)
            rect(-8, 12, 14, 7, radius: 1, Theme.card)
            symbol("drop.fill", -1, 15.5, size: 4, Theme.water)
        } else {
            rect(-8, 0, 16, 20, radius: 3, Theme.wood)
            rect(-8, 5, 16, 1.4, Theme.woodDark)
            rect(-8, 14, 16, 1.4, Theme.woodDark)
            oval(0, 20, 8, 2, Theme.water)
            stem(10, 34, 10, 22, width: 2.4, Color(white: 0.62))
            stem(10, 22, 4, 20.5, width: 2.4, Color(white: 0.62))
        }
    }

    private func tote(_ x: CGFloat, _ color: Color) {
        rect(x - 4, 11, 8, 8, radius: 1, color)
        var handle = Path()
        handle.move(to: pt(x - 2.5, 19))
        handle.addQuadCurve(to: pt(x + 2.5, 19), control: pt(x, 24))
        ctx.stroke(handle, with: .color(color.mix(with: .black, by: 0.2)), lineWidth: 0.8 * u)
    }

    private func refillOrMarket(_ big: Bool) {
        if big {
            rect(-25, 0, 1.6, 27, Theme.woodDark)
            rect(23.4, 0, 1.6, 27, Theme.woodDark)
            rect(-24, 8, 48, 3, Theme.wood)
            rect(-22, 0, 1.4, 8, Theme.woodDark)
            rect(20.6, 0, 1.4, 8, Theme.woodDark)
            for i in 0..<6 {
                rect(-26 + CGFloat(i) * 8.67, 26, 8.67, 6, i % 2 == 0 ? Theme.petal : .white)
            }
            tote(-13, Theme.sage)
            tote(0, Theme.sunflower)
            tote(13, Theme.water)
        } else {
            rect(-5, 0, 10, 22, radius: 2, Color(white: 0.78))
            rect(-7, 20, 14, 6, radius: 2, Theme.water)
            stem(5, 22, 9, 18, width: 1.5, Color(white: 0.5))
            symbol("drop.fill", 0, 11, size: 6, .white)
        }
    }

    private func donationBox(_ big: Bool) {
        if big {
            rect(-1.5, 0, 3, 16, Theme.woodDark)
            rect(-10, 16, 20, 16, Color(red: 0.75, green: 0.32, blue: 0.28))
            gableRoof(-12, 12, base: 32, peak: 40, Theme.woodDark)
            rect(-7, 19, 14, 10, Color(red: 0.86, green: 0.92, blue: 0.96))
            rect(-6, 19.5, 2, 6, Theme.sunflower)
            rect(-3.5, 19.5, 2, 7, Theme.water)
            rect(-1, 19.5, 2, 5.5, Theme.leaf)
            rect(1.5, 19.5, 2, 6.5, Theme.petal)
        } else {
            rect(-10, 0, 20, 18, radius: 1.5, Color(red: 0.36, green: 0.52, blue: 0.70))
            rect(-6, 14, 12, 1.6, Theme.bark)
            symbol("heart.fill", 0, 8, size: 6, .white)
        }
    }
}

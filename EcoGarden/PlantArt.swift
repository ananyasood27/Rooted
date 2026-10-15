import SwiftUI

// Hand-drawn garden art. Every item has four growth stages and each stage is its own
// drawing (different silhouette and height), not just a bigger copy of the last one.
//
// All art is drawn in a "design space" measured in units: x runs -60...60 around the
// plant's base, y runs upward from the ground (0) to ~110. PlantSprite scales that to
// whatever size it is given.

extension GardenItemKind {
    /// Living plants bend and yellow as they dry out; bins, barrels and insects don't.
    var isPlant: Bool { self == .seedling || self == .flower || self == .tree }

    /// Structures stand still; everything else leans gently in the breeze.
    var swaysInWind: Bool { self != .compostBin && self != .rainBarrel }

    /// Rough width/height of the drawn art at each stage, in design units —
    /// used for tap areas, ground shadows and positioning labels around the art.
    func footprint(stage: Int) -> CGSize {
        let table: [(CGFloat, CGFloat)]
        switch self {
        case .seedling: table = [(28, 24), (36, 44), (58, 44), (76, 56)]
        case .flower: table = [(26, 18), (32, 46), (34, 66), (58, 78)]
        case .tree: table = [(28, 26), (34, 62), (68, 88), (96, 110)]
        case .compostBin: table = [(52, 40), (52, 44), (52, 62), (70, 58)]
        case .rainBarrel: table = [(42, 50), (42, 56), (64, 90), (70, 90)]
        case .butterfly: table = [(44, 34), (56, 44), (46, 64), (50, 84)]
        }
        let entry = table[min(max(stage, 0), table.count - 1)]
        return CGSize(width: entry.0, height: entry.1)
    }
}

struct PlantSprite: View {
    let kind: GardenItemKind
    let stage: Int
    var health: Double = 100
    /// Width of the sprite's frame in points. Height follows from `designSize`.
    var size: CGFloat = 110

    static let designSize = CGSize(width: 120, height: 132)
    /// Design units between the bottom of the frame and the ground line.
    static let groundInset: CGFloat = 10
    /// Where the plant meets the ground — the anchor to rotate/scale around.
    static let groundAnchor = UnitPoint(x: 0.5, y: (designSize.height - groundInset) / designSize.height)

    /// 0 while healthy, rising to 1 as health runs out.
    private var wilt: Double { min(1, max(0, (60 - health) / 60)) }

    var body: some View {
        Group {
            if kind == .butterfly && stage >= 3 {
                // Only the adult butterfly moves on its own (wing beats + hovering).
                TimelineView(.animation) { timeline in
                    art(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                art(time: 0)
            }
        }
        .frame(width: size, height: size * Self.designSize.height / Self.designSize.width)
        .saturation(1 - wilt * 0.35)
        // Decorative for VoiceOver — whatever shows the sprite describes it in words.
        .accessibilityHidden(true)
    }

    private func art(time: Double) -> some View {
        Canvas { ctx, canvasSize in
            let unit = canvasSize.width / Self.designSize.width
            let painter = PlantPainter(
                ctx: ctx,
                u: unit,
                origin: CGPoint(x: canvasSize.width / 2, y: canvasSize.height - Self.groundInset * unit),
                wilt: wilt,
                bends: kind.isPlant
            )
            painter.draw(kind, stage: stage, time: time)
        }
    }
}

// MARK: - Painter

/// Draws in design units onto a Canvas. Also used for the community buildings in TownArt.swift.
struct PlantPainter {
    let ctx: GraphicsContext
    /// Points per design unit.
    let u: CGFloat
    /// The base of the plant (design 0,0) in canvas points.
    let origin: CGPoint
    let wilt: Double
    let bends: Bool

    // MARK: Primitives

    /// Design point -> canvas point. A wilting plant slumps: the higher a point is,
    /// the further it leans over and the more it sinks.
    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        var dx = x
        var dy = y
        if bends {
            dx += CGFloat(wilt) * 0.0012 * y * y
            dy *= 1 - 0.12 * CGFloat(wilt)
        }
        return CGPoint(x: origin.x + dx * u, y: origin.y - dy * u)
    }

    func foliage(_ color: Color) -> Color {
        color.mix(with: Theme.wilt, by: wilt * 0.65)
    }

    func oval(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ color: Color) {
        let c = pt(x, y)
        let rect = CGRect(x: c.x - rx * u, y: c.y - ry * u, width: rx * 2 * u, height: ry * 2 * u)
        ctx.fill(Path(ellipseIn: rect), with: .color(color))
    }

    func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ color: Color) {
        oval(x, y, r, r, color)
    }

    func blobs(_ list: [(CGFloat, CGFloat, CGFloat)], _ color: Color) {
        for b in list { dot(b.0, b.1, b.2, color) }
    }

    /// Axis-aligned box with its bottom-left corner at (x, y).
    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, radius: CGFloat = 0, _ color: Color) {
        let topLeft = pt(x, y + h)
        let r = CGRect(x: topLeft.x, y: topLeft.y, width: w * u, height: h * u)
        ctx.fill(Path(roundedRect: r, cornerRadius: radius * u), with: .color(color))
    }

    func poly(_ points: [(CGFloat, CGFloat)], _ color: Color) {
        var p = Path()
        for (i, q) in points.enumerated() {
            if i == 0 { p.move(to: pt(q.0, q.1)) } else { p.addLine(to: pt(q.0, q.1)) }
        }
        p.closeSubpath()
        ctx.fill(p, with: .color(color))
    }

    /// A curved line from one point to another; `bow` pushes the middle sideways.
    func stem(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat, bow: CGFloat = 0, width: CGFloat, _ color: Color) {
        var p = Path()
        p.move(to: pt(x0, y0))
        p.addQuadCurve(to: pt(x1, y1), control: pt((x0 + x1) / 2 + bow, (y0 + y1) / 2))
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width * u, lineCap: .round))
    }

    /// A pointed leaf growing out of (x, y). `angle` is degrees from straight up,
    /// positive to the right. Leaves hang lower as the plant wilts.
    func leaf(_ x: CGFloat, _ y: CGFloat, angle: Double, length: CGFloat, width: CGFloat, _ color: Color, droops: Bool = true) {
        var a = angle
        if droops { a += (angle < 0 ? -1 : 1) * wilt * 50 }
        let r = a * .pi / 180
        let dx = CGFloat(sin(r))
        let dy = CGFloat(cos(r))
        let mx = x + dx * length * 0.45
        let my = y + dy * length * 0.45
        var p = Path()
        p.move(to: pt(x, y))
        p.addQuadCurve(to: pt(x + dx * length, y + dy * length), control: pt(mx + dy * width, my - dx * width))
        p.addQuadCurve(to: pt(x, y), control: pt(mx - dy * width, my + dx * width))
        ctx.fill(p, with: .color(color))
    }

    func mound(_ w: CGFloat) {
        oval(0, 0, w, w * 0.30, Theme.soil)
        oval(-w * 0.15, w * 0.08, w * 0.6, w * 0.14, Theme.soil.mix(with: .white, by: 0.14))
    }

    func bloom(_ x: CGFloat, _ y: CGFloat, r: CGFloat, _ petal: Color) {
        let color = petal.mix(with: Theme.wilt, by: wilt * 0.6)
        for i in 0..<7 {
            leaf(x, y, angle: Double(i) * 360 / 7 + 12, length: r, width: r * 0.75, color, droops: false)
        }
        dot(x, y, r * 0.30, Theme.sunflower)
        dot(x - r * 0.08, y + r * 0.08, r * 0.14, Theme.sunflower.mix(with: .white, by: 0.45))
    }

    // MARK: Dispatch

    func draw(_ kind: GardenItemKind, stage: Int, time: Double) {
        switch kind {
        case .seedling: shrub(stage)
        case .flower: flower(stage)
        case .tree: tree(stage)
        case .compostBin: compostBin(stage)
        case .rainBarrel: rainBarrel(stage)
        case .butterfly: butterfly(stage, time: time)
        }
    }

    // MARK: Seedling -> berry bush

    private func shrub(_ stage: Int) {
        let light = foliage(Theme.leafLight)
        let mid = foliage(Theme.leaf)
        let dark = foliage(Theme.leafDark)

        switch stage {
        case 0:
            mound(13)
            stem(0, 1, 0, 11, width: 1.6, light)
            leaf(0, 11, angle: -58, length: 10, width: 6, light)
            leaf(0, 11, angle: 58, length: 10, width: 6, mid)
        case 1:
            mound(15)
            stem(0, 1, 1, 30, bow: 2, width: 2, mid)
            leaf(0.5, 11, angle: -62, length: 14, width: 8, mid)
            leaf(0.5, 12, angle: 62, length: 14, width: 8, dark)
            leaf(1, 21, angle: -48, length: 13, width: 7, light)
            leaf(1, 22, angle: 50, length: 13, width: 7, mid)
            leaf(1, 30, angle: -14, length: 11, width: 6, light)
            leaf(1, 30, angle: 24, length: 10, width: 6, mid)
        case 2:
            mound(21)
            stem(-3, 1, -7, 12, width: 2, Theme.trunk)
            stem(3, 1, 7, 12, width: 2, Theme.trunk)
            leaf(-22, 17, angle: -75, length: 8, width: 5, dark)
            leaf(22, 16, angle: 75, length: 8, width: 5, dark)
            leaf(0, 37, angle: 8, length: 8, width: 5, mid)
            blobs([(-14, 16, 12), (14, 15, 12), (0, 26, 14)], dark)
            blobs([(0, 17, 15), (-8, 24, 9), (9, 23, 9)], mid)
            blobs([(-6, 28, 5), (7, 20, 4), (-13, 18, 4)], light)
        default:
            mound(28)
            stem(-4, 1, -10, 14, width: 2.4, Theme.trunk)
            stem(4, 1, 10, 14, width: 2.4, Theme.trunk)
            leaf(-33, 22, angle: -72, length: 9, width: 5, dark)
            leaf(33, 22, angle: 72, length: 9, width: 5, dark)
            leaf(-12, 48, angle: -20, length: 9, width: 5, mid)
            leaf(13, 49, angle: 22, length: 9, width: 5, mid)
            blobs([(-21, 19, 15), (21, 19, 15), (-10, 35, 16), (11, 36, 16)], dark)
            blobs([(0, 22, 19), (-14, 27, 11), (14, 28, 11), (0, 40, 12)], mid)
            blobs([(-8, 42, 6), (10, 32, 5), (-18, 28, 5), (4, 24, 4)], light)
            let berries: [(CGFloat, CGFloat)] = [(-20, 20), (-9, 30), (3, 17), (15, 24), (22, 33), (-3, 43), (9, 41), (-15, 37)]
            let berry = Theme.berry.mix(with: Theme.wilt, by: wilt * 0.5)
            for b in berries {
                dot(b.0, b.1, 2.4, berry)
                dot(b.0 - 0.7, b.1 + 0.7, 0.8, .white.opacity(0.6))
            }
        }
    }

    // MARK: Flower: sprout -> bud -> bloom -> bouquet

    private func flower(_ stage: Int) {
        let light = foliage(Theme.leafLight)
        let mid = foliage(Theme.leaf)
        let dark = foliage(Theme.leafDark)

        switch stage {
        case 0:
            mound(12)
            stem(0, 1, 0, 10, width: 1.5, light)
            leaf(0, 10, angle: -30, length: 7, width: 4, light)
            leaf(0, 10, angle: 45, length: 8, width: 4.5, mid)
            dot(0.3, 11.5, 1.3, Theme.petal)
        case 1:
            mound(14)
            stem(0, 1, 1, 34, bow: 2, width: 1.8, mid)
            leaf(0.6, 10, angle: -58, length: 14, width: 7, mid)
            leaf(0.8, 16, angle: 60, length: 13, width: 7, dark)
            // closed bud: green sepals with the petal colour just showing
            oval(1, 37, 3.6, 5.5, mid)
            oval(1, 41, 2.2, 3.2, Theme.petal.mix(with: Theme.wilt, by: wilt * 0.6))
        case 2:
            mound(16)
            stem(0, 1, 0, 48, bow: 3, width: 2, mid)
            leaf(0.8, 10, angle: -58, length: 15, width: 8, mid)
            leaf(1.2, 18, angle: 60, length: 15, width: 8, dark)
            leaf(1.4, 28, angle: -45, length: 11, width: 6, light)
            bloom(0, 51, r: 12, Theme.petal)
        default:
            mound(22)
            leaf(-6, 1, angle: -40, length: 13, width: 7, dark)
            leaf(6, 1, angle: 42, length: 13, width: 7, mid)
            stem(-2, 1, -18, 42, bow: -5, width: 1.9, mid)
            stem(2, 1, 17, 46, bow: 5, width: 1.9, dark)
            stem(0, 1, 0, 58, bow: 2, width: 2.2, mid)
            leaf(-1, 10, angle: -62, length: 16, width: 8, mid)
            leaf(1, 12, angle: 62, length: 16, width: 8, dark)
            leaf(0.5, 26, angle: -48, length: 13, width: 7, light)
            leaf(1, 30, angle: 50, length: 12, width: 6, mid)
            bloom(-18, 45, r: 9, Theme.petalLight)
            bloom(17, 49, r: 9.5, Theme.lilac)
            bloom(0, 62, r: 13, Theme.petal)
        }
    }

    // MARK: Tree: sprout -> sapling -> young tree -> grand tree

    private func tree(_ stage: Int) {
        let light = foliage(Theme.leafLight)
        let mid = foliage(Theme.leaf)
        let dark = foliage(Theme.leafDark)
        let bark = Theme.trunk
        let barkDark = Theme.trunkDark

        switch stage {
        case 0:
            mound(13)
            stem(0, 1, 0.5, 15, bow: 1, width: 2, bark.mix(with: Theme.leaf, by: 0.3))
            leaf(0.3, 8, angle: 70, length: 6, width: 4, mid)
            leaf(0.5, 15, angle: -35, length: 9, width: 5.5, light)
            leaf(0.5, 15, angle: 40, length: 9, width: 5.5, mid)
        case 1:
            mound(15)
            stem(0, 1, 0, 40, bow: 1.5, width: 3, bark)
            stem(0.5, 20, 9, 29, width: 1.5, bark)
            leaf(9, 29, angle: 50, length: 9, width: 5, mid)
            blobs([(-7, 42, 9), (7, 43, 9)], dark)
            blobs([(0, 48, 11)], mid)
            blobs([(-3, 51, 5), (4, 46, 3.5)], light)
        case 2:
            mound(22)
            poly([(-5, 0), (5, 0), (3, 40), (-3, 40)], bark)
            poly([(1, 0), (5, 0), (3, 40), (1.5, 40)], barkDark)
            stem(0, 30, -12, 44, width: 2.4, bark)
            stem(0, 32, 12, 46, width: 2.4, barkDark)
            blobs([(-17, 52, 15), (17, 52, 15), (0, 68, 17)], dark)
            blobs([(0, 54, 19), (-9, 64, 13), (10, 63, 12)], mid)
            blobs([(-8, 66, 7), (6, 58, 5), (-14, 54, 5)], light)
        default:
            mound(30)
            // root flare
            poly([(-7, 0), (-17, 0), (-5, 10)], bark)
            poly([(7, 0), (17, 0), (5, 10)], barkDark)
            poly([(-8, 0), (8, 0), (4.5, 46), (-4.5, 46)], bark)
            poly([(2, 0), (8, 0), (4.5, 46), (2, 46)], barkDark)
            stem(0, 34, -20, 54, bow: -2, width: 3.4, bark)
            stem(0, 38, 21, 56, bow: 2, width: 3.4, barkDark)
            blobs([(-29, 60, 17), (29, 60, 17), (-15, 82, 19), (15, 83, 19), (0, 94, 14)], dark)
            blobs([(0, 66, 24), (-18, 68, 16), (19, 70, 15), (0, 84, 18)], mid)
            blobs([(-10, 86, 9), (8, 74, 7), (-22, 70, 6), (16, 86, 6)], light)
            let fruit: [(CGFloat, CGFloat)] = [(-20, 62), (-6, 72), (12, 64), (24, 72), (2, 90), (-14, 84)]
            let fruitColor = Theme.berry.mix(with: Theme.wilt, by: wilt * 0.5)
            for f in fruit {
                dot(f.0, f.1, 2.8, fruitColor)
                dot(f.0 - 0.8, f.1 + 0.8, 0.9, .white.opacity(0.6))
            }
        }
    }

    // MARK: Compost bin: empty -> scraps -> steaming heap -> rich soil

    private func compostBin(_ stage: Int) {
        // shadowed interior, seen through the gaps between slats
        rect(-21, 2, 42, 30, Theme.compost.opacity(0.9))

        // contents go in before the front slats so the bin partly hides them
        switch stage {
        case 1:
            oval(0, 32, 15, 5, Color(red: 0.46, green: 0.36, blue: 0.22))
            dot(-6, 34.5, 2.2, Color(red: 0.93, green: 0.56, blue: 0.20))
            leaf(3, 33, angle: 40, length: 7, width: 4, Theme.leafLight, droops: false)
            dot(9, 33.5, 1.7, Color(white: 0.93))
        case 2:
            oval(0, 33, 20, 10, Color(red: 0.36, green: 0.27, blue: 0.17))
            dot(-9, 39, 2.4, Color(red: 0.93, green: 0.56, blue: 0.20))
            leaf(-2, 41, angle: -35, length: 8, width: 4.5, Theme.leafLight, droops: false)
            leaf(6, 40, angle: 50, length: 7, width: 4, Theme.leaf, droops: false)
            dot(11, 38, 1.8, Color(white: 0.93))
            dot(1, 38, 1.6, Color(red: 0.78, green: 0.66, blue: 0.30))
        case 3:
            oval(0, 33, 21, 12, Theme.compost)
            oval(-5, 38, 10, 4, Theme.compost.mix(with: .white, by: 0.10))
        default:
            break
        }

        for i in 0..<4 {
            let slat = i % 2 == 0 ? Theme.wood : Theme.wood.mix(with: Theme.woodDark, by: 0.25)
            rect(-22, 2 + CGFloat(i) * 8, 44, 6, radius: 1, slat)
        }
        rect(-24, 0, 5, 37, radius: 1, Theme.woodDark)
        rect(19, 0, 5, 37, radius: 1, Theme.woodDark)

        if stage == 2 {
            // warmth rising off an active heap
            let steam = Color.white.opacity(0.55)
            stem(-9, 46, -8, 57, bow: 3, width: 1.2, steam)
            stem(0, 48, 1, 60, bow: -3, width: 1.2, steam)
            stem(9, 46, 9, 56, bow: 3, width: 1.2, steam)
        }
        if stage >= 3 {
            // finished compost: things start growing out of it
            stem(-7, 43, -7, 52, width: 1.2, Theme.leafLight)
            leaf(-7, 52, angle: -45, length: 6, width: 4, Theme.leafLight, droops: false)
            leaf(-7, 52, angle: 45, length: 6, width: 4, Theme.leaf, droops: false)
            stem(8, 42, 9, 49, width: 1.2, Theme.leaf)
            leaf(9, 49, angle: 30, length: 6, width: 4, Theme.leafLight, droops: false)
            stem(-2, 44.5, 4, 44.5, bow: 0, width: 1.3, Color(red: 0.86, green: 0.55, blue: 0.55))
            // mushrooms at the foot of the bin
            rect(-32.2, 0, 2.4, 6, radius: 1, Color(white: 0.92))
            oval(-31, 7, 5, 3.2, Color(red: 0.72, green: 0.30, blue: 0.22))
            rect(29.4, 0, 1.8, 4, radius: 0.8, Color(white: 0.92))
            oval(30.3, 4.8, 3.6, 2.4, Color(red: 0.72, green: 0.30, blue: 0.22))
            leaf(-27, 0, angle: 15, length: 8, width: 3, Theme.leafLight, droops: false)
            leaf(26, 0, angle: -18, length: 7, width: 3, Theme.leaf, droops: false)
        }
    }

    // MARK: Rain barrel: empty -> collecting -> filling -> overflowing

    private func rainBarrel(_ stage: Int) {
        let metal = Color(red: 0.62, green: 0.66, blue: 0.70)
        let hoop = Color(red: 0.30, green: 0.30, blue: 0.32)
        let brass = Color(red: 0.78, green: 0.62, blue: 0.28)
        // from stage 1 the barrel sits on a stand so a watering can fits under the tap
        let lift: CGFloat = stage >= 1 ? 6 : 0

        if stage >= 1 {
            rect(-16, 0, 9, 6, radius: 1, Theme.woodDark)
            rect(7, 0, 9, 6, radius: 1, Theme.woodDark)
        }
        if stage >= 2 {
            // downspout feeding the barrel
            stem(27, 90, 27, lift + 58, width: 5, metal)
            stem(27, lift + 58, 9, lift + 47, width: 5, metal)
            rect(23.5, 78, 7, 2.5, hoop)
        }

        var body = Path()
        body.move(to: pt(-15, lift))
        body.addQuadCurve(to: pt(-15, lift + 44), control: pt(-21, lift + 22))
        body.addLine(to: pt(15, lift + 44))
        body.addQuadCurve(to: pt(15, lift), control: pt(21, lift + 22))
        body.closeSubpath()
        ctx.fill(body, with: .color(Theme.wood))
        for x in [-8, 0, 8] as [CGFloat] {
            stem(x, lift + 1, x, lift + 43, bow: x * 0.25, width: 0.6, Theme.woodDark.opacity(0.55))
        }
        stem(-17.2, lift + 10, 17.2, lift + 10, width: 2.2, hoop)
        stem(-17.2, lift + 34, 17.2, lift + 34, width: 2.2, hoop)

        // open top — you can see water once it's full
        oval(0, lift + 44, 15, 4, Theme.woodDark)
        oval(0, lift + 44, 12.5, 3, stage >= 3 ? Theme.water : Theme.compost)
        if stage >= 3 { oval(-4, lift + 44.6, 4, 0.9, .white.opacity(0.55)) }

        // level gauge
        let level: CGFloat = [0, 1.0 / 3, 2.0 / 3, 1][min(max(stage, 0), 3)]
        rect(-2.5, lift + 13, 5, 19, radius: 2.5, Color(red: 0.18, green: 0.20, blue: 0.24))
        if level > 0 {
            rect(-1.7, lift + 13.8, 3.4, 17.4 * level, radius: 1.7, Theme.water)
        }

        if stage >= 1 {
            rect(-3, lift + 3, 6, 3, radius: 1, brass)
            rect(-1, lift + 0.5, 2, 3, brass)
        }
        if stage >= 3 {
            // overflowing: drips, a puddle, and the damp ground has come alive
            dot(0, lift - 2, 1, Theme.water)
            oval(0, -1, 9, 2, Theme.water.opacity(0.6))
            dot(-12, lift + 3, 3.4, Theme.leaf.opacity(0.85))
            dot(-9, lift + 1.5, 2.4, Theme.leafLight.opacity(0.85))
            dot(12, lift + 2, 2.6, Theme.leaf.opacity(0.85))
            leaf(-22, 0, angle: -20, length: 10, width: 3.5, Theme.leafLight, droops: false)
            leaf(-26, 0, angle: 12, length: 8, width: 3, Theme.leaf, droops: false)
            stem(-31, 0, -32, 10, width: 1.1, Theme.leaf)
            bloom(-32, 11, r: 4.5, Theme.petal)
            stem(-24, 0, -23, 7, width: 1.1, Theme.leaf)
            bloom(-23, 8, r: 3.6, Theme.petalLight)
        }
    }

    // MARK: Butterfly: egg -> caterpillar -> chrysalis -> butterfly

    private func butterfly(_ stage: Int, time: Double) {
        let light = Theme.leafLight
        let mid = Theme.leaf
        let dark = Theme.leafDark

        switch stage {
        case 0:
            mound(12)
            stem(0, 1, -2, 20, bow: -2, width: 1.8, mid)
            leaf(-1, 10, angle: -60, length: 12, width: 7, dark, droops: false)
            leaf(-2, 19, angle: 68, length: 26, width: 13, mid, droops: false)
            // a clutch of eggs on the big leaf
            let egg = Color(red: 0.98, green: 0.95, blue: 0.80)
            oval(7, 23.5, 1.5, 1.9, egg)
            oval(10.6, 24.8, 1.5, 1.9, egg)
            oval(9, 21.4, 1.5, 1.9, egg)
        case 1:
            mound(13)
            stem(0, 1, 1, 30, bow: 2, width: 2, mid)
            leaf(0.5, 15, angle: -62, length: 15, width: 8, dark, droops: false)
            leaf(1, 30, angle: -20, length: 10, width: 6, light, droops: false)
            leaf(1, 28, angle: 75, length: 28, width: 14, mid, droops: false)
            // caterpillar inching along the leaf
            let green = Color(red: 0.62, green: 0.80, blue: 0.25)
            let yellow = Color(red: 0.95, green: 0.84, blue: 0.30)
            for i in 0..<6 {
                let d = 6 + CGFloat(i) * 3.2
                let hump: CGFloat = (i == 2 || i == 3) ? 1.6 : 0
                dot(1 + 0.966 * d, 30.4 + 0.259 * d + hump, 2.4, i % 2 == 0 ? green : yellow)
            }
            dot(25.6, 37, 2.5, Color(red: 0.25, green: 0.18, blue: 0.12))
            dot(26.4, 37.8, 0.6, .white)
        case 2:
            mound(13)
            stem(0, 1, -1, 50, bow: -3, width: 2.4, Theme.trunk)
            stem(-2, 44, 18, 50, width: 1.8, Theme.trunk)
            leaf(-1.5, 26, angle: -65, length: 13, width: 7, dark, droops: false)
            leaf(-1, 50, angle: -30, length: 12, width: 7, mid, droops: false)
            leaf(18, 50, angle: 60, length: 11, width: 6, light, droops: false)
            // chrysalis hanging from the branch
            stem(10, 47.5, 10, 44, width: 0.6, .white.opacity(0.85))
            oval(10, 36, 4.2, 8.5, Color(red: 0.42, green: 0.66, blue: 0.42))
            oval(11.2, 37, 1.6, 6, Color(red: 0.62, green: 0.82, blue: 0.56))
            let gold = Color(red: 0.90, green: 0.75, blue: 0.30)
            stem(6.6, 40, 13.4, 40, width: 0.9, gold)
            dot(8.5, 33, 0.7, gold)
            dot(11.5, 31, 0.7, gold)
        default:
            mound(13)
            stem(0, 1, 0, 26, bow: 1.5, width: 1.8, mid)
            leaf(0, 10, angle: -58, length: 11, width: 6, mid, droops: false)
            leaf(0.5, 13, angle: 60, length: 11, width: 6, dark, droops: false)
            bloom(0, 28, r: 8, Theme.petalLight)

            // hovering over the flower, wings beating
            let bx = 8 + CGFloat(sin(time * 0.9)) * 4
            let by = 60 + CGFloat(sin(time * 2.1)) * 3
            let flap = 0.35 + 0.65 * abs(CGFloat(sin(time * 7)))
            let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
            let amber = Color(red: 0.98, green: 0.74, blue: 0.28)
            let ink = Color(red: 0.18, green: 0.14, blue: 0.12)
            for side in [-1, 1] as [CGFloat] {
                let s = side * flap
                var lower = Path()
                lower.move(to: pt(bx, by))
                lower.addQuadCurve(to: pt(bx + 12 * s, by - 12), control: pt(bx + 15 * s, by - 1))
                lower.addQuadCurve(to: pt(bx, by - 5), control: pt(bx + 3 * s, by - 13))
                lower.closeSubpath()
                ctx.fill(lower, with: .color(amber))
                ctx.stroke(lower, with: .color(ink), lineWidth: 0.9 * u)

                var upper = Path()
                upper.move(to: pt(bx, by + 2))
                upper.addQuadCurve(to: pt(bx + 18 * s, by + 16), control: pt(bx + 4 * s, by + 20))
                upper.addQuadCurve(to: pt(bx + 14 * s, by), control: pt(bx + 23 * s, by + 6))
                upper.addLine(to: pt(bx, by - 1))
                upper.closeSubpath()
                ctx.fill(upper, with: .color(orange))
                ctx.stroke(upper, with: .color(ink), lineWidth: 1.1 * u)
                dot(bx + 15.5 * s, by + 13, 1.1, .white)
                dot(bx + 16.5 * s, by + 8, 0.9, .white)

                stem(bx, by + 6, bx + 4 * side, by + 13, bow: side, width: 0.5, ink)
            }
            oval(bx, by, 1.5, 7, ink)
        }
    }
}

#Preview("All stages") {
    let kinds: [GardenItemKind] = [.seedling, .flower, .tree, .compostBin, .rainBarrel, .butterfly]
    return ScrollView {
        VStack(spacing: 4) {
            ForEach(kinds, id: \.self) { kind in
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { stage in
                        PlantSprite(kind: kind, stage: stage, size: 90)
                    }
                }
            }
            // thirsty versions
            HStack(spacing: 0) {
                ForEach([GardenItemKind.seedling, .flower, .tree], id: \.self) { kind in
                    PlantSprite(kind: kind, stage: 3, health: 5, size: 90)
                }
            }
        }
    }
    .background(Color(red: 0.45, green: 0.66, blue: 0.38))
}

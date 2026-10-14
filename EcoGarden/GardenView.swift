import SwiftUI

struct GardenView: View {
    @EnvironmentObject var appState: AppState
    @State private var now = Date()
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    /// The scrollable yard is bigger than the screen in both directions —
    /// makes it feel like a real sprawling plot rather than a fixed tile.
    private let canvasHeight: CGFloat = 1700
    private let maxZoom: CGFloat = 2.2

    /// 1 = natural size. Clamped per-device so you can never zoom out past the edge of the yard.
    @State private var zoom: CGFloat = 1
    @State private var pinchStartZoom: CGFloat? = nil
    @State private var scrollPosition = ScrollPosition()
    @State private var scrollOffset = ScrollOffsetBox()
    /// Hidden presenter controls — press and hold the "Your Garden" title to show them.
    @State private var showDemoControls = false

    private var phase: DayPhase { DayPhase(date: now) }

    var body: some View {
        GeometryReader { screenGeo in
            let insets = screenGeo.safeAreaInsets
            let viewport = CGSize(
                width: screenGeo.size.width + insets.leading + insets.trailing,
                height: screenGeo.size.height + insets.top + insets.bottom
            )
            let canvasWidth = max(screenGeo.size.width * 1.9, 720)
            let zoomRange = max(viewport.width / canvasWidth, viewport.height / canvasHeight)...maxZoom
            let scale = min(max(zoom, zoomRange.lowerBound), zoomRange.upperBound)
            // Scenery continues past every edge of the yard, far enough that a rubber-band
            // overscroll shows more landscape instead of a blank page — even fully zoomed out.
            let bleed = CGSize(
                width: viewport.width * 0.5 / zoomRange.lowerBound,
                height: viewport.height * 0.5 / zoomRange.lowerBound
            )

            ZStack(alignment: .bottomTrailing) {
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    ZStack(alignment: .top) {
                        Color.clear
                            .overlay {
                                YardBackground(width: canvasWidth, height: canvasHeight, bleed: bleed, phase: phase)
                            }

                        PlantLayer(canvasSize: CGSize(width: canvasWidth, height: canvasHeight), now: now, phase: phase, zoom: scale)
                            .environmentObject(appState)

                        if phase != .night {
                            SkyBirds(width: canvasWidth)
                        }

                        if appState.placedItems.isEmpty {
                            EmptyYardCard()
                                .position(x: canvasWidth / 2, y: canvasHeight * 0.48)
                        }
                    }
                    .frame(width: canvasWidth, height: canvasHeight)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: canvasWidth * scale, height: canvasHeight * scale, alignment: .topLeading)
                }
                .scrollPosition($scrollPosition)
                // Open on the middle of the yard instead of the top-left corner, which is all sky.
                .defaultScrollAnchor(.center, for: .initialOffset)
                .onScrollGeometryChange(for: CGPoint.self) { $0.contentOffset } action: { _, offset in
                    scrollOffset.value = offset
                }
                .simultaneousGesture(
                    MagnifyGesture()
                        .onChanged { value in
                            let start = pinchStartZoom ?? scale
                            pinchStartZoom = start
                            setZoom(start * value.magnification, from: scale, in: zoomRange, viewport: viewport)
                        }
                        .onEnded { _ in pinchStartZoom = nil }
                )
                .ignoresSafeArea()

                zoomButtons(scale: scale, range: zoomRange, viewport: viewport)
                    .padding(.trailing, 14)
                    .padding(.bottom, 52)
            }
        }
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                topBar
                if showDemoControls {
                    demoControls.transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .overlay(alignment: .bottom) { hintPill }
        .onAppear { now = appState.now }
        .onReceive(ticker) { _ in now = appState.now }
        .onChange(of: appState.demoTimeOffset) { _, _ in
            withAnimation(.easeInOut(duration: 0.6)) { now = appState.now }
        }
    }

    /// For recording a demo: skip the garden's clock ahead (to show thirst and nightfall)
    /// and top up coins, without waiting hours or grinding tasks.
    private var demoControls: some View {
        HStack(spacing: 8) {
            Text("DEMO")
                .font(Theme.caption(10))
                .foregroundColor(Theme.sunflower)
                .tracking(1)
            Text(now.formatted(date: .omitted, time: .shortened))
                .font(Theme.caption(12))
                .foregroundColor(.white)
            Spacer(minLength: 4)
            demoButton("+3 hrs") { appState.demoTimeOffset += 3 * 3600 }
            demoButton("+100 coins") { appState.coins += 100 }
            demoButton("Reset") { appState.demoTimeOffset = 0 }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(.black.opacity(0.45)))
        .padding(.horizontal, 14)
    }

    private func demoButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.caption(11))
                .foregroundColor(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(.white.opacity(0.18)))
        }
        .buttonStyle(.plain)
    }

    /// Changes zoom while keeping whatever is at the centre of the screen at the centre.
    private func setZoom(_ target: CGFloat, from current: CGFloat, in range: ClosedRange<CGFloat>, viewport: CGSize) {
        let newZoom = min(max(target, range.lowerBound), range.upperBound)
        guard newZoom != current else { return }
        let centerX = (scrollOffset.value.x + viewport.width / 2) / current
        let centerY = (scrollOffset.value.y + viewport.height / 2) / current
        zoom = newZoom
        scrollPosition.scrollTo(point: CGPoint(
            x: max(0, centerX * newZoom - viewport.width / 2),
            y: max(0, centerY * newZoom - viewport.height / 2)
        ))
    }

    private func zoomButtons(scale: CGFloat, range: ClosedRange<CGFloat>, viewport: CGSize) -> some View {
        VStack(spacing: 0) {
            zoomButton("plus", enabled: scale < range.upperBound - 0.001, label: "Zoom in") {
                setZoom(scale * 1.3, from: scale, in: range, viewport: viewport)
            }
            Rectangle().fill(.white.opacity(0.2)).frame(width: 24, height: 1)
            zoomButton("minus", enabled: scale > range.lowerBound + 0.001, label: "Zoom out") {
                setZoom(scale / 1.3, from: scale, in: range, viewport: viewport)
            }
        }
        .background(Capsule().fill(.black.opacity(0.35)))
    }

    private func zoomButton(_ icon: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(enabled ? 1 : 0.35))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(Theme.moss).frame(width: 30, height: 30)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(-10))
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("Your Garden")
                        .font(Theme.display(17, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(appState.placedItems.count) planted")
                        .font(Theme.body(11))
                        .foregroundColor(.white.opacity(0.75))
                }
            }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.8) {
                withAnimation(.easeInOut(duration: 0.25)) { showDemoControls.toggle() }
            }

            Spacer()

            if appState.streak > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill").foregroundColor(Theme.ember)
                    Text("\(appState.streak)").foregroundColor(.white)
                }
                .font(Theme.display(13, weight: .semibold))
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(Capsule().fill(.white.opacity(0.16)))
            }

            HStack(spacing: 5) {
                Circle().fill(Theme.sunflower).frame(width: 16, height: 16)
                    .overlay(Image(systemName: "leaf.fill").font(.system(size: 8, weight: .bold)).foregroundColor(Theme.moss))
                Text("\(appState.coins)")
                    .font(Theme.display(14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.16)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.black.opacity(0.30))
                .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .padding(.horizontal, 14)
        .padding(.top, 6)
    }

    private var hintPill: some View {
        Text("Tap to care for a plant • drag to move it • pinch to zoom")
            .font(Theme.body(11.5))
            .foregroundColor(.white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(.black.opacity(0.35)))
            .padding(.bottom, 10)
    }
}

/// Latest scroll offset, kept in a reference box so tracking it doesn't redraw the garden on every scroll tick.
private final class ScrollOffsetBox {
    var value: CGPoint = .zero
}

private struct EmptyYardCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("🌱")
                .font(.system(size: 34))
            Text("Your yard is empty")
                .font(Theme.display(16, weight: .semibold))
                .foregroundColor(Theme.bark)
            Text("Finish a task or visit the Shop\nto plant something.")
                .font(Theme.body(12.5))
                .foregroundColor(Theme.stone)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(.white.opacity(0.85))
        )
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }
}

// MARK: - Time of day

/// The garden follows the real clock: sky, lighting and what's out all change with it.
private enum DayPhase {
    case dawn, day, dusk, night

    init(date: Date) {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<8: self = .dawn
        case 8..<17: self = .day
        case 17..<20: self = .dusk
        default: self = .night
        }
    }

    var skyColors: [Color] {
        switch self {
        case .dawn: return [Color(red: 0.98, green: 0.75, blue: 0.55), Color(red: 0.86, green: 0.88, blue: 0.80)]
        case .day: return [Color(red: 0.45, green: 0.72, blue: 0.93), Color(red: 0.82, green: 0.92, blue: 0.95)]
        case .dusk: return [Color(red: 0.42, green: 0.36, blue: 0.60), Color(red: 0.97, green: 0.62, blue: 0.45)]
        case .night: return [Color(red: 0.05, green: 0.07, blue: 0.20), Color(red: 0.16, green: 0.22, blue: 0.36)]
        }
    }

    /// How strongly the ground is darkened by the evening/night shade.
    var groundShade: Double {
        switch self {
        case .dawn: return 0.08
        case .day: return 0
        case .dusk: return 0.16
        case .night: return 0.46
        }
    }

    /// Multiplied into plant art so it sits in the same light as the ground.
    var spriteTint: Color {
        switch self {
        case .dawn: return Color(red: 1.0, green: 0.95, blue: 0.90)
        case .day: return .white
        case .dusk: return Color(red: 0.95, green: 0.84, blue: 0.82)
        case .night: return Color(red: 0.58, green: 0.62, blue: 0.82)
        }
    }
}

/// Deterministic random numbers, so scenery lands in the same place on every redraw.
private struct SeededRandom: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// `count` scattered points: x and y in 0...1 plus a spare 0...1 value for variety.
private func scatter(count: Int, seed: UInt64) -> [(x: CGFloat, y: CGFloat, v: CGFloat)] {
    var rng = SeededRandom(state: seed)
    var points: [(x: CGFloat, y: CGFloat, v: CGFloat)] = []
    for _ in 0..<count {
        let x = CGFloat.random(in: 0...1, using: &rng)
        let y = CGFloat.random(in: 0...1, using: &rng)
        let v = CGFloat.random(in: 0...1, using: &rng)
        points.append((x: x, y: y, v: v))
    }
    return points
}

// MARK: - Background: sky, sun/moon, clouds, hills, fence, lawn

private struct YardBackground: View {
    let width: CGFloat
    let height: CGFloat
    /// Extra scenery beyond each edge of the yard, only ever seen while overscrolling.
    let bleed: CGSize
    let phase: DayPhase

    private let shade = Color(red: 0.05, green: 0.08, blue: 0.24)

    var body: some View {
        let totalHeight = height + bleed.height * 2
        let horizonY = bleed.height + height * YardGround.horizon

        ZStack(alignment: .topLeading) {
            // Above the yard the sky just carries on in its topmost colour.
            phase.skyColors[0]

            LinearGradient(colors: phase.skyColors, startPoint: .top, endPoint: .bottom)
                .frame(height: height * YardGround.horizon)
                .offset(y: bleed.height)

            if phase == .night {
                StarField()
                    .frame(height: horizonY)
            }

            CelestialBody(isNight: phase == .night)
                .position(x: bleed.width + width * 0.78, y: bleed.height + 110)

            DriftingClouds(width: width)
                .opacity(phase == .night ? 0.30 : 1)
                .offset(x: bleed.width, y: bleed.height)

            YardGround(yard: CGSize(width: width, height: height), sideBleed: bleed.width)
                .frame(height: height + bleed.height)
                .offset(y: bleed.height)

            // Evening and night light: darkens the land, leaves the sky alone.
            LinearGradient(
                stops: [
                    .init(color: shade.opacity(0), location: (horizonY - height * 0.07) / totalHeight),
                    .init(color: shade.opacity(phase.groundShade), location: (horizonY + height * 0.01) / totalHeight),
                    .init(color: shade.opacity(phase.groundShade), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
        .frame(width: width + bleed.width * 2, height: totalHeight)
        .clipped()
        .allowsHitTesting(false)
    }
}

private struct CelestialBody: View {
    let isNight: Bool

    var body: some View {
        let core = isNight ? Color(red: 0.93, green: 0.93, blue: 0.98) : Color(red: 1.0, green: 0.90, blue: 0.55)
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [core.opacity(0.55), core.opacity(0)], center: .center, startRadius: 18, endRadius: 80))
                .frame(width: 160, height: 160)
            Circle().fill(core).frame(width: 46, height: 46)
            if isNight {
                // craters
                Circle().fill(Color.black.opacity(0.08)).frame(width: 11, height: 11).offset(x: -8, y: -6)
                Circle().fill(Color.black.opacity(0.07)).frame(width: 7, height: 7).offset(x: 9, y: 4)
                Circle().fill(Color.black.opacity(0.06)).frame(width: 5, height: 5).offset(x: -3, y: 11)
            }
        }
    }
}

private struct StarField: View {
    private static let stars = scatter(count: 90, seed: 3)

    var body: some View {
        Canvas { ctx, size in
            for star in Self.stars {
                let r = 0.6 + star.v * 1.1
                // fade out toward the horizon, where the sky is brighter
                let alpha = (0.35 + star.v * 0.6) * (1 - star.y * 0.8)
                let rect = CGRect(x: star.x * size.width - r, y: star.y * size.height - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
            }
        }
    }
}

private struct DriftingClouds: View {
    let width: CGFloat
    @State private var drift: CGFloat = 0

    var body: some View {
        ZStack {
            CloudShape().position(x: width * 0.22 + drift, y: 80)
            CloudShape(scale: 0.7).position(x: width * 0.58 - drift * 0.6, y: 150)
            CloudShape(scale: 1.25).position(x: width * 0.90 + drift * 0.4, y: 250)
            CloudShape(scale: 0.55).position(x: width * 0.38 + drift * 0.8, y: 300)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) {
                drift = 26
            }
        }
    }
}

/// A puffy cumulus: rounded lobes on a flat base, lit from above.
private struct CloudShape: View {
    var scale: CGFloat = 1.0

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(alignment: .bottom, spacing: -16 * scale) {
                Circle().frame(width: 30 * scale, height: 30 * scale)
                Circle().frame(width: 48 * scale, height: 48 * scale)
                Circle().frame(width: 38 * scale, height: 38 * scale)
                Circle().frame(width: 24 * scale, height: 24 * scale)
            }
            .offset(y: -5 * scale)
            Capsule().frame(width: 100 * scale, height: 20 * scale)
        }
        .foregroundStyle(LinearGradient(colors: [.white, Color(red: 0.84, green: 0.88, blue: 0.93)], startPoint: .top, endPoint: .bottom))
        .opacity(0.92)
    }
}

/// A few distant birds wheeling in the sky — purely ambient, not interactive.
private struct SkyBirds: View {
    let width: CGFloat

    private let birds: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (0.30, 190, 15), (0.34, 204, 11), (0.66, 120, 13)
    ]

    var body: some View {
        ForEach(0..<birds.count, id: \.self) { i in
            GlidingBird(size: birds[i].size)
                .position(x: width * birds[i].x, y: birds[i].y)
        }
        .allowsHitTesting(false)
    }
}

private struct GlidingBird: View {
    let size: CGFloat
    @State private var offset: CGSize = .zero

    var body: some View {
        BirdShape()
            .stroke(Color(red: 0.20, green: 0.22, blue: 0.28).opacity(0.7), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .frame(width: size, height: size * 0.4)
            .offset(offset)
            .onAppear {
                withAnimation(.easeInOut(duration: Double.random(in: 5...8)).repeatForever(autoreverses: true)) {
                    offset = CGSize(width: CGFloat.random(in: 20...46), height: CGFloat.random(in: -12...12))
                }
            }
    }
}

private struct BirdShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.7))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY * 0.6), control: CGPoint(x: rect.width * 0.28, y: rect.minY - rect.height * 0.4))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.7), control: CGPoint(x: rect.width * 0.72, y: rect.minY - rect.height * 0.4))
        return p
    }
}

/// Everything from the horizon down, drawn in one pass: hazy far hills with a treeline,
/// a nearer hill, a picket fence with a gate gap, the lawn, a dirt path that widens
/// toward the viewer, and scattered grass tufts, wildflowers and pebbles.
private struct YardGround: View {
    /// Fraction of the canvas height where the lawn meets the hills.
    static let horizon: CGFloat = 0.34

    private static let tufts = scatter(count: 1100, seed: 11)
    private static let wildflowers = scatter(count: 280, seed: 23)
    private static let pebbles = scatter(count: 60, seed: 37)
    private static let treeline = scatter(count: 70, seed: 5)

    /// The yard itself. The view is drawn larger than this: `sideBleed` wider on the left
    /// and right, and however much taller its frame is at the bottom.
    let yard: CGSize
    let sideBleed: CGFloat

    /// Centre of the dirt path at depth t (0 at the fence, 1 at the bottom edge).
    private static func laneCenter(_ t: CGFloat, width: CGFloat) -> CGFloat {
        width * (0.5 + 0.16 * sin(t * 5.0) * (0.25 + 0.75 * t))
    }

    /// The path is narrow far away and wide up close, which is most of what sells the depth.
    private static func laneHalfWidth(_ t: CGFloat) -> CGFloat {
        9 + 30 * t
    }

    private static func ridgeY(_ fx: CGFloat, baseY: CGFloat, amp: CGFloat, phase: CGFloat) -> CGFloat {
        baseY - amp * (0.6 * sin(fx * 4.1 + phase) + 0.4 * sin(fx * 9.3 + phase * 2.3))
    }

    private static func ridge(_ size: CGSize, baseY: CGFloat, amp: CGFloat, phase: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: size.height))
        let steps = 48
        for i in 0...steps {
            let fx = CGFloat(i) / CGFloat(steps)
            p.addLine(to: CGPoint(x: fx * size.width, y: ridgeY(fx, baseY: baseY, amp: amp, phase: phase)))
        }
        p.addLine(to: CGPoint(x: size.width, y: size.height))
        p.closeSubpath()
        return p
    }

    var body: some View {
        Canvas { ctx, size in
            let w = yard.width
            let h = yard.height
            let ox = sideBleed
            let horizon = h * Self.horizon
            let lawnFar = Color(red: 0.55, green: 0.74, blue: 0.42)
            let lawnNear = Color(red: 0.27, green: 0.50, blue: 0.26)

            // Far hills — pale and bluish, the way distance looks through haze
            ctx.fill(
                Self.ridge(size, baseY: horizon - 34, amp: 26, phase: 0.6),
                with: .linearGradient(
                    Gradient(colors: [Color(red: 0.58, green: 0.72, blue: 0.66), Color(red: 0.68, green: 0.80, blue: 0.66)]),
                    startPoint: CGPoint(x: 0, y: horizon - 70), endPoint: CGPoint(x: 0, y: horizon)
                )
            )
            for tree in Self.treeline {
                let y = Self.ridgeY(tree.x, baseY: horizon - 34, amp: 26, phase: 0.6)
                let r = 5 + tree.v * 5
                let crown = CGRect(x: tree.x * size.width - r, y: y - r * 1.5, width: r * 2, height: r * 2.3)
                ctx.fill(Path(ellipseIn: crown), with: .color(Color(red: 0.36, green: 0.54, blue: 0.46)))
            }

            // Near hill, blending into the far edge of the lawn
            ctx.fill(
                Self.ridge(size, baseY: horizon - 8, amp: 12, phase: 2.4),
                with: .linearGradient(
                    Gradient(colors: [Color(red: 0.50, green: 0.70, blue: 0.44), lawnFar]),
                    startPoint: CGPoint(x: 0, y: horizon - 24), endPoint: CGPoint(x: 0, y: horizon + 4)
                )
            )

            // Lawn: lighter in the distance, richer up close
            ctx.fill(
                Path(CGRect(x: 0, y: horizon, width: size.width, height: size.height - horizon)),
                with: .linearGradient(
                    Gradient(colors: [lawnFar, lawnNear]),
                    startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: h)
                )
            )

            // Picket fence along the back of the yard, with a gap where the path comes in
            let fenceBase = horizon + 14
            let gate = ox + Self.laneCenter(0, width: w)
            let gateHalf: CGFloat = 13
            let picket = Color(red: 0.93, green: 0.90, blue: 0.82)
            let picketShade = Color(red: 0.74, green: 0.70, blue: 0.60)
            ctx.fill(Path(CGRect(x: 0, y: fenceBase - 1, width: size.width, height: 5)), with: .color(.black.opacity(0.10)))
            for railY in [fenceBase - 8, fenceBase - 17] {
                ctx.fill(Path(CGRect(x: 0, y: railY, width: gate - gateHalf, height: 2.5)), with: .color(picketShade))
                ctx.fill(Path(CGRect(x: gate + gateHalf, y: railY, width: size.width - gate - gateHalf, height: 2.5)), with: .color(picketShade))
            }
            var px: CGFloat = 3
            while px < size.width {
                if abs(px + 3 - gate) > gateHalf {
                    var board = Path()
                    board.move(to: CGPoint(x: px, y: fenceBase))
                    board.addLine(to: CGPoint(x: px, y: fenceBase - 20))
                    board.addLine(to: CGPoint(x: px + 3, y: fenceBase - 24))
                    board.addLine(to: CGPoint(x: px + 6, y: fenceBase - 20))
                    board.addLine(to: CGPoint(x: px + 6, y: fenceBase))
                    board.closeSubpath()
                    ctx.fill(board, with: .color(picket))
                    ctx.fill(Path(CGRect(x: px + 4.5, y: fenceBase - 20, width: 1.5, height: 20)), with: .color(picketShade))
                }
                px += 11
            }
            for postX in [gate - gateHalf - 3, gate + gateHalf - 3] {
                ctx.fill(Path(roundedRect: CGRect(x: postX, y: fenceBase - 29, width: 6, height: 30), cornerRadius: 1.5), with: .color(picketShade))
            }

            // Dirt path
            let laneTop = fenceBase - 6
            // t runs past 1 so the path keeps going through the scenery below the yard
            let tMax = (size.height - laneTop) / (h - laneTop)
            let steps = 56
            var lane = Path()
            for i in 0...steps {
                let t = tMax * CGFloat(i) / CGFloat(steps)
                let point = CGPoint(x: ox + Self.laneCenter(t, width: w) - Self.laneHalfWidth(t), y: laneTop + (h - laneTop) * t)
                if i == 0 { lane.move(to: point) } else { lane.addLine(to: point) }
            }
            for i in stride(from: steps, through: 0, by: -1) {
                let t = tMax * CGFloat(i) / CGFloat(steps)
                lane.addLine(to: CGPoint(x: ox + Self.laneCenter(t, width: w) + Self.laneHalfWidth(t), y: laneTop + (h - laneTop) * t))
            }
            lane.closeSubpath()
            ctx.fill(
                lane,
                with: .linearGradient(
                    Gradient(colors: [Color(red: 0.80, green: 0.70, blue: 0.54), Color(red: 0.66, green: 0.53, blue: 0.38)]),
                    startPoint: CGPoint(x: 0, y: laneTop), endPoint: CGPoint(x: 0, y: h)
                )
            )
            ctx.stroke(lane, with: .color(Theme.soil.opacity(0.30)), lineWidth: 2)

            for pebble in Self.pebbles {
                let t = pebble.y * tMax
                let x = ox + Self.laneCenter(t, width: w) + (pebble.x * 2 - 1) * Self.laneHalfWidth(t) * 0.8
                let r = (1.2 + pebble.v * 2) * (0.5 + t)
                let rect = CGRect(x: x - r, y: laneTop + (h - laneTop) * t - r * 0.35, width: r * 2, height: r * 1.3)
                ctx.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.50, green: 0.44, blue: 0.36).opacity(0.55)))
            }

            // Grass tufts and wildflowers — bigger toward the viewer, none on the path
            let turfTop = fenceBase + 8
            func onLane(_ x: CGFloat, _ y: CGFloat, margin: CGFloat) -> Bool {
                let t = max(0, (y - laneTop) / (h - laneTop))
                return abs(x - ox - Self.laneCenter(t, width: w)) < Self.laneHalfWidth(t) + margin
            }
            let bladeDark = Color(red: 0.16, green: 0.38, blue: 0.20).opacity(0.55)
            let bladeLight = Color(red: 0.62, green: 0.80, blue: 0.42).opacity(0.60)
            let bladeTips: [(CGFloat, CGFloat)] = [(-3.5, -7), (0.5, -10), (4, -6.5)]
            for tuft in Self.tufts {
                let x = tuft.x * size.width
                let y = turfTop + tuft.y * (size.height - turfTop)
                if onLane(x, y, margin: 5) { continue }
                let s = 0.55 + (y - turfTop) / (h - turfTop) * 0.9
                var blades = Path()
                for tip in bladeTips {
                    blades.move(to: CGPoint(x: x, y: y))
                    blades.addQuadCurve(
                        to: CGPoint(x: x + tip.0 * s, y: y + tip.1 * s),
                        control: CGPoint(x: x + tip.0 * s * 0.2, y: y + tip.1 * s * 0.7)
                    )
                }
                ctx.stroke(blades, with: .color(tuft.v > 0.5 ? bladeDark : bladeLight), style: StrokeStyle(lineWidth: 1.4 * s, lineCap: .round))
            }
            for flower in Self.wildflowers {
                let x = flower.x * size.width
                let y = turfTop + flower.y * (size.height - turfTop)
                if onLane(x, y, margin: 4) { continue }
                let r = 1.3 * (0.55 + (y - turfTop) / (h - turfTop) * 0.9)
                let color: Color = flower.v < 0.4 ? .white : (flower.v < 0.75 ? Theme.sunflower : Theme.petalLight)
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(color.opacity(0.85)))
            }
        }
    }
}

// MARK: - Plants layer

private struct PlantLayer: View {
    @EnvironmentObject var appState: AppState
    let canvasSize: CGSize
    let now: Date
    let phase: DayPhase
    let zoom: CGFloat
    @State private var selectedID: UUID? = nil

    /// Drags are measured in this space so the numbers stay steady while the plant itself moves.
    static let space = "yard"

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { selectedID = nil }

            ForEach(appState.placedItems) { placed in
                if let item = appState.shopItems.first(where: { $0.id == placed.itemID }) {
                    DraggablePlant(
                        placed: placed,
                        item: item,
                        canvasSize: canvasSize,
                        now: now,
                        phase: phase,
                        zoom: zoom,
                        isSelected: selectedID == placed.id,
                        onSelect: { selectedID = (selectedID == placed.id) ? nil : placed.id }
                    )
                    .environmentObject(appState)
                    // Lower on the canvas = closer to the viewer = drawn in front.
                    .zIndex(placed.y + (selectedID == placed.id ? 10 : 0))
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .coordinateSpace(.named(Self.space))
    }
}

private struct DraggablePlant: View {
    @EnvironmentObject var appState: AppState
    let placed: PlacedItem
    let item: GardenItem
    let canvasSize: CGSize
    let now: Date
    let phase: DayPhase
    let zoom: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void

    @GestureState private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var waterPulse = false
    @State private var showLevelUp = false
    @State private var showCantAfford = false
    @State private var swaying = false

    /// Where the plant meets the ground.
    private var basePosition: CGPoint {
        CGPoint(x: placed.x * canvasSize.width, y: placed.y * canvasSize.height)
    }

    private var health: Double { placed.health(asOf: now) }
    private var isThirsty: Bool { health < 40 }

    /// Plants further down the yard are nearer the viewer, so they draw larger.
    private var depthScale: CGFloat {
        let range = AppState.yardYRange
        let t = (placed.y - range.lowerBound) / (range.upperBound - range.lowerBound)
        return 0.74 + 0.44 * CGFloat(min(max(t, 0), 1))
    }

    private var spriteWidth: CGFloat { 112 * CGFloat(placed.scale) * depthScale }
    private var spriteHeight: CGFloat { spriteWidth * PlantSprite.designSize.height / PlantSprite.designSize.width }
    /// Points per design unit of the art (see PlantArt.swift).
    private var unit: CGFloat { spriteWidth / PlantSprite.designSize.width }
    private var groundInset: CGFloat { PlantSprite.groundInset * unit }
    private var artSize: CGSize {
        let f = item.kind.footprint(stage: placed.stage)
        return CGSize(width: f.width * unit, height: f.height * unit)
    }

    private var tilt: Double {
        guard item.kind.swaysInWind else { return 0 }
        return placed.rotation * 0.4 + (swaying ? 1.6 : -1.6)
    }

    var body: some View {
        ZStack {
            PlantSprite(kind: item.kind, stage: placed.stage, health: health, size: spriteWidth)
                .id(placed.stage)
                .transition(.scale(scale: 0.55, anchor: PlantSprite.groundAnchor).combined(with: .opacity))
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.6), value: placed.stage)
        .colorMultiply(phase.spriteTint)
        .rotationEffect(.degrees(tilt), anchor: PlantSprite.groundAnchor)
        .scaleEffect((isDragging ? 1.08 : 1.0) * (waterPulse ? 1.12 : 1.0), anchor: PlantSprite.groundAnchor)
        .animation(.interpolatingSpring(stiffness: 260, damping: 9), value: waterPulse)
        .allowsHitTesting(false)
        .background(alignment: .bottom) { contactShadow }
        .overlay(alignment: .bottom) { touchArea }
        .overlay(alignment: .bottom) { levelPips.offset(y: 5) }
        .overlay(alignment: .bottom) {
            if isThirsty && !isSelected {
                thirstBadge.offset(x: artSize.width / 2, y: -(groundInset + artSize.height))
            }
        }
        .overlay(alignment: .bottom) {
            if showLevelUp {
                ZStack {
                    SparkleBurst()
                    LevelUpLabel(text: item.kind.stageNames[placed.stage] + "!")
                }
                .offset(y: -(groundInset + artSize.height / 2))
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottom) {
            if isSelected {
                // Counter-scaled so the card stays the same size on screen at any zoom level.
                callout
                    .fixedSize()
                    .scaleEffect(1 / zoom, anchor: .bottom)
                    .offset(y: -(groundInset + artSize.height + 10))
                    .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
            }
        }
        .position(
            x: basePosition.x + dragOffset.width,
            y: basePosition.y + dragOffset.height - spriteHeight / 2 + groundInset
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .onAppear {
            // Each plant gets its own rhythm so the garden doesn't sway in unison.
            let period = 2.2 + Double(abs(placed.id.hashValue % 100)) / 100
            withAnimation(.easeInOut(duration: period).repeatForever(autoreverses: true)) {
                swaying = true
            }
        }
        .onChange(of: placed.stage) { _, _ in
            showLevelUp = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showLevelUp = false }
        }
    }

    // MARK: Pieces

    /// Soft shadow where the plant meets the lawn — lifts and spreads while it's being carried.
    private var contactShadow: some View {
        let width = max(artSize.width * 0.85, 22)
        let height = width * 0.22
        return Ellipse()
            .fill(Color.black.opacity(isDragging ? 0.12 : 0.20))
            .frame(width: width * (isDragging ? 1.2 : 1), height: height)
            .blur(radius: 2)
            .offset(y: -(groundInset - height / 2) + (isDragging ? 6 : 0))
    }

    /// The tappable/draggable region, sized to the drawn art rather than the whole sprite frame.
    private var touchArea: some View {
        Color.clear
            .frame(width: max(44, artSize.width), height: max(44, artSize.height + groundInset))
            .contentShape(Rectangle())
            // The art is drawn, not text, so VoiceOver needs to be told what this is.
            .accessibilityElement()
            .accessibilityLabel(accessibilityDescription)
            .accessibilityHint("Opens care options")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onSelect() }
            .gesture(
                // minimumDistance 0 so a plain, no-movement tap still registers and calls onEnded —
                // otherwise stationary taps never satisfy a drag gesture and the callout never shows.
                DragGesture(minimumDistance: 0, coordinateSpace: .named(PlantLayer.space))
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                        if abs(value.translation.width) > 4 || abs(value.translation.height) > 4 {
                            isDragging = true
                        }
                    }
                    .onEnded { value in
                        let dist = (value.translation.width * value.translation.width
                            + value.translation.height * value.translation.height).squareRoot()
                        if dist < 6 {
                            onSelect()
                        } else {
                            let newX = (basePosition.x + value.translation.width) / canvasSize.width
                            let newY = (basePosition.y + value.translation.height) / canvasSize.height
                            appState.moveItem(id: placed.id, x: newX, y: newY)
                        }
                        isDragging = false
                    }
            )
    }

    private var accessibilityDescription: String {
        var parts = [item.name, "level \(placed.stage + 1) of 4", item.kind.stageNames[placed.stage]]
        if isThirsty { parts.append("needs \(item.kind.careGerund.lowercased())") }
        return parts.joined(separator: ", ")
    }

    /// Four dots, one lit per level reached — readable without opening the callout.
    private var levelPips: some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(i <= placed.stage ? Theme.sunflower : Color.white.opacity(0.40))
                    .frame(width: 5, height: 5)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(Capsule().fill(.black.opacity(0.30)))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var thirstBadge: some View {
        Image(systemName: item.kind.careIcon)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 18, height: 18)
            .background(Circle().fill(careColor))
            .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Button/badge colour matching the kind of care: water, compost, nectar.
    private var careColor: Color {
        switch item.kind {
        case .compostBin: return Theme.soil
        case .butterfly: return Theme.petal
        default: return Theme.water
        }
    }

    private var growthHint: String {
        guard let remaining = placed.careUntilNextStage else { return "Fully grown" }
        let next = item.kind.stageNames[min(placed.stage + 1, 3)]
        return "\(remaining) more \(item.kind.careCountNoun(remaining)) to \(next)"
    }

    private var callout: some View {
        VStack(spacing: 6) {
            VStack(spacing: 1) {
                Text(item.name)
                    .font(Theme.display(13, weight: .semibold))
                    .foregroundColor(Theme.bark)
                Text("Level \(placed.stage + 1) of 4 · \(item.kind.stageNames[placed.stage])")
                    .font(Theme.caption(11))
                    .foregroundColor(Theme.stone)
            }

            ZStack(alignment: .leading) {
                Capsule().fill(Theme.stone.opacity(0.18)).frame(width: 120, height: 5)
                Capsule().fill(healthColor).frame(width: max(5, 120 * CGFloat(health) / 100), height: 5)
            }

            Text(growthHint)
                .font(Theme.body(10.5))
                .foregroundColor(Theme.stone)

            Button(action: water) {
                HStack(spacing: 4) {
                    Image(systemName: item.kind.careIcon)
                    Text(item.kind.careVerb)
                    Text("-\(appState.wateringCost)")
                        .foregroundColor(.white.opacity(0.75))
                }
                .font(Theme.caption())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(careColor))
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .alert("Not enough EcoCoins", isPresented: $showCantAfford) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\(item.kind.careGerund) costs \(appState.wateringCost) coins. Complete tasks to earn more.")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                .fill(.white.opacity(0.95))
        )
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
    }

    private func water() {
        let success = appState.waterItem(id: placed.id)
        guard success else {
            showCantAfford = true
            return
        }
        waterPulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { waterPulse = false }
    }

    private var healthColor: Color {
        if health > 65 { return Theme.moss }
        if health > 35 { return Theme.sunflower }
        return Color(red: 0.75, green: 0.30, blue: 0.25)
    }
}

/// Names the stage a plant just reached, drifting up and fading — plays once per level-up.
private struct LevelUpLabel: View {
    let text: String
    @State private var risen = false

    var body: some View {
        Text(text)
            .font(Theme.display(13, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(Theme.moss))
            .fixedSize()
            .offset(y: risen ? -30 : 0)
            .opacity(risen ? 0 : 1)
            .onAppear {
                withAnimation(.easeIn(duration: 1.4)) { risen = true }
            }
    }
}

/// A burst of little sparkles that fan outward and fade — plays once when a plant levels up.
private struct SparkleBurst: View {
    @State private var expanded = false
    private let angles: [Double] = Array(stride(from: 0.0, to: 360.0, by: 45.0))

    var body: some View {
        ZStack {
            ForEach(angles.indices, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.sunflower)
                    .offset(
                        x: expanded ? cos(angles[i] * .pi / 180) * 34 : 0,
                        y: expanded ? sin(angles[i] * .pi / 180) * 34 : 0
                    )
                    .scaleEffect(expanded ? 0.4 : 1.1)
                    .opacity(expanded ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.75)) { expanded = true }
        }
    }
}

#Preview {
    GardenView().environmentObject(AppState())
}

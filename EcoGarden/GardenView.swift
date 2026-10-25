import SwiftUI

struct GardenView: View {
    @EnvironmentObject var appState: AppState
    @State private var now = Date()
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private let canvasHeight: CGFloat = 1700
    private let maxZoom: CGFloat = 2.2

    // 1 = natural size
    @State private var zoom: CGFloat = 1
    @State private var pinch: PinchStart? = nil
    @State private var scrollPosition = ScrollPosition()
    @State private var scrollOffset = ScrollOffsetBox()
    // Long-press the title to show.
    @State private var showDemoControls = false
    @State private var showLevels = false

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
            // Draw scenery past the edges so overscrolling doesn't show blank space.
            let bleed = CGSize(
                width: viewport.width * 0.5 / zoomRange.lowerBound,
                height: viewport.height * 0.5 / zoomRange.lowerBound
            )

            ZStack(alignment: .bottomTrailing) {
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    ZStack(alignment: .top) {
                        Color.clear
                            .overlay {
                                YardBackground(
                                    width: canvasWidth, height: canvasHeight, bleed: bleed, phase: phase,
                                    bikeLane: appState.upgradeTier(for: .travel) >= 2
                                )
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
                    .onAppear { scrollToNewItem(canvasWidth: canvasWidth, scale: scale, viewport: viewport) }
                    .onChange(of: appState.newlyPlacedID) { _, _ in
                        scrollToNewItem(canvasWidth: canvasWidth, scale: scale, viewport: viewport)
                    }
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: canvasWidth * scale, height: canvasHeight * scale, alignment: .topLeading)
                }
                .scrollPosition($scrollPosition)
                // Start on the street instead of the top-left (all sky).
                .defaultScrollAnchor(UnitPoint(x: 0.5, y: 0.3), for: .initialOffset)
                .onScrollGeometryChange(for: CGPoint.self) { $0.contentOffset } action: { _, offset in
                    scrollOffset.value = offset
                }
                // turn off scrolling while pinching so the two don't fight
                .scrollDisabled(pinch != nil)
                .simultaneousGesture(
                    MagnifyGesture()
                        .onChanged { value in
                            let start = pinch ?? {
                                // save where the pinch started, otherwise the zoom drifts
                                let fingers = CGPoint(x: value.startAnchor.x * viewport.width, y: value.startAnchor.y * viewport.height)
                                let start = PinchStart(
                                    zoom: scale,
                                    fingers: fingers,
                                    canvasPoint: CGPoint(
                                        x: (scrollOffset.value.x + fingers.x) / scale,
                                        y: (scrollOffset.value.y + fingers.y) / scale
                                    )
                                )
                                pinch = start
                                return start
                            }()
                            setZoom(
                                start.zoom * value.magnification, keeping: start.canvasPoint, at: start.fingers,
                                in: zoomRange, canvasWidth: canvasWidth, viewport: viewport
                            )
                        }
                        .onEnded { _ in pinch = nil }
                )
                .ignoresSafeArea()

                zoomButtons(scale: scale, range: zoomRange, canvasWidth: canvasWidth, viewport: viewport)
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
        .sheet(isPresented: $showLevels) {
            CommunityLevelSheet().environmentObject(appState)
        }
        .onAppear { now = appState.now }
        .onReceive(ticker) { _ in now = appState.now }
        .onChange(of: appState.demoTimeOffset) { _, _ in
            withAnimation(.easeInOut(duration: 0.6)) { now = appState.now }
        }
    }

    // Demo controls for recording the video.
    private var demoControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("DEMO")
                    .font(Theme.caption(10))
                    .foregroundColor(Theme.sunflower)
                    .tracking(1)
                Text(now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                    .font(Theme.caption(12))
                    .foregroundColor(.white)
                Spacer(minLength: 4)
                demoButton("Reset") { appState.demoTimeOffset = 0 }
            }
            HStack(spacing: 8) {
                demoButton("+3 hrs") { appState.demoTimeOffset += 3 * 3600 }
                demoButton("+1 week") { appState.demoTimeOffset += 7 * 86_400 }
                demoButton("+100 coins") { appState.coins += 100 }
                demoButton("+10 pts") { appState.addDemoPoints() }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.black.opacity(0.45)))
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

    private func scrollToNewItem(canvasWidth: CGFloat, scale: CGFloat, viewport: CGSize) {
        guard let id = appState.newlyPlacedID,
              let placed = appState.placedItems.first(where: { $0.id == id }) else { return }
        // Aim a little above the base so the whole plant is in view, not just its roots.
        let target = CGPoint(
            x: max(0, placed.x * canvasWidth * scale - viewport.width / 2),
            y: max(0, (placed.y * canvasHeight - 50) * scale - viewport.height / 2)
        )
        // Run after the scroll view's first layout.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.6)) { scrollPosition.scrollTo(point: target) }
        }
    }

    // Zoom while keeping canvasPoint under screenPoint. Clamped so it can't scroll past the edges.
    private func setZoom(
        _ target: CGFloat, keeping canvasPoint: CGPoint, at screenPoint: CGPoint,
        in range: ClosedRange<CGFloat>, canvasWidth: CGFloat, viewport: CGSize
    ) {
        let newZoom = min(max(target, range.lowerBound), range.upperBound)
        let maxX = max(0, canvasWidth * newZoom - viewport.width)
        let maxY = max(0, canvasHeight * newZoom - viewport.height)
        zoom = newZoom
        scrollPosition.scrollTo(point: CGPoint(
            x: min(max(canvasPoint.x * newZoom - screenPoint.x, 0), maxX),
            y: min(max(canvasPoint.y * newZoom - screenPoint.y, 0), maxY)
        ))
    }

    // for the + and - buttons, zooms around the middle of the screen
    private func zoomAroundCenter(by factor: CGFloat, scale: CGFloat, range: ClosedRange<CGFloat>, canvasWidth: CGFloat, viewport: CGSize) {
        let center = CGPoint(x: viewport.width / 2, y: viewport.height / 2)
        let canvasPoint = CGPoint(
            x: (scrollOffset.value.x + center.x) / scale,
            y: (scrollOffset.value.y + center.y) / scale
        )
        setZoom(scale * factor, keeping: canvasPoint, at: center, in: range, canvasWidth: canvasWidth, viewport: viewport)
    }

    private func zoomButtons(scale: CGFloat, range: ClosedRange<CGFloat>, canvasWidth: CGFloat, viewport: CGSize) -> some View {
        VStack(spacing: 0) {
            zoomButton("plus", enabled: scale < range.upperBound - 0.001, label: "Zoom in") {
                zoomAroundCenter(by: 1.3, scale: scale, range: range, canvasWidth: canvasWidth, viewport: viewport)
            }
            Rectangle().fill(.white.opacity(0.2)).frame(width: 24, height: 1)
            zoomButton("minus", enabled: scale > range.lowerBound + 0.001, label: "Zoom out") {
                zoomAroundCenter(by: 1 / 1.3, scale: scale, range: range, canvasWidth: canvasWidth, viewport: viewport)
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
                    Text("Your Community")
                        .font(Theme.display(17, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(appState.placedItems.count) plants · \(placesBuilt) places")
                        .font(Theme.body(11))
                        .foregroundColor(.white.opacity(0.75))
                }
            }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.8) {
                withAnimation(.easeInOut(duration: 0.25)) { showDemoControls.toggle() }
            }

            Spacer()

            Button { showLevels = true } label: {
                HStack(spacing: 5) {
                    LevelRing(
                        level: appState.communityLevel,
                        progress: CommunityLevel.progress(forPoints: appState.communityPoints),
                        size: 22,
                        light: true
                    )
                    Text("Level").foregroundColor(.white)
                }
                .font(Theme.display(13, weight: .semibold))
                .padding(.leading, 4).padding(.trailing, 9).padding(.vertical, 4)
                .background(Capsule().fill(.white.opacity(0.16)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Community level \(appState.communityLevel + 1), \(CommunityLevel.names[appState.communityLevel])")

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

    private var placesBuilt: Int {
        VolunteerCategory.allCases.filter { appState.volunteerHours(in: $0) >= 1 }.count
    }

    private var hintPill: some View {
        Text("Tap anything to learn more • drag plants • pinch to zoom")
            .font(Theme.body(11.5))
            .foregroundColor(.white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(.black.opacity(0.35)))
            .padding(.bottom, 10)
    }
}

private struct PinchStart {
    let zoom: CGFloat
    let fingers: CGPoint     // on screen
    let canvasPoint: CGPoint // unscaled canvas point under the fingers
}

// class instead of @State so scrolling doesn't redraw everything
private final class ScrollOffsetBox {
    var value: CGPoint = .zero
}

private struct EmptyYardCard: View {
    var body: some View {
        VStack(spacing: 8) {
            IconTile(systemName: "leaf.fill", tint: Theme.forest, size: 40)
                .padding(.bottom, 2)
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
                .fill(Theme.card.opacity(0.95))
        )
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }
}

// MARK: - Time of day

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

    var groundShade: Double {
        switch self {
        case .dawn: return 0.08
        case .day: return 0
        case .dusk: return 0.16
        case .night: return 0.46
        }
    }

    var spriteTint: Color {
        switch self {
        case .dawn: return Color(red: 1.0, green: 0.95, blue: 0.90)
        case .day: return .white
        case .dusk: return Color(red: 0.95, green: 0.84, blue: 0.82)
        case .night: return Color(red: 0.58, green: 0.62, blue: 0.82)
        }
    }
}

// Seeded so scenery stays put between redraws.
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
    let bleed: CGSize
    let phase: DayPhase
    var bikeLane = false

    private let shade = Color(red: 0.05, green: 0.08, blue: 0.24)

    var body: some View {
        let totalHeight = height + bleed.height * 2
        let horizonY = bleed.height + height * YardGround.horizon

        ZStack(alignment: .topLeading) {
            // Above the yard the sky just carries on in its top color.
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

            YardGround(yard: CGSize(width: width, height: height), sideBleed: bleed.width, bikeLane: bikeLane)
                .frame(height: height + bleed.height)
                .offset(y: bleed.height)

            // Darken the land at dusk/night, not the sky.
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

private struct YardGround: View {
    static let horizon: CGFloat = 0.30
    // Where buildings stand, below the horizon.
    static let lotLine: CGFloat = 62
    static let fenceOffset: CGFloat = 128

    private static let tufts = scatter(count: 1100, seed: 11)
    private static let wildflowers = scatter(count: 280, seed: 23)
    private static let pebbles = scatter(count: 60, seed: 37)
    private static let treeline = scatter(count: 70, seed: 5)

    // The view is drawn bigger than this to cover the overscroll area.
    let yard: CGSize
    let sideBleed: CGFloat
    var bikeLane = false

    // t: 0 at the fence, 1 at the bottom edge
    private static func laneCenter(_ t: CGFloat, width: CGFloat) -> CGFloat {
        width * (0.5 + 0.16 * sin(t * 5.0) * (0.25 + 0.75 * t))
    }

    // wider at the bottom so it looks like perspective
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

            // Far hills
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

            // Near hill
            ctx.fill(
                Self.ridge(size, baseY: horizon - 8, amp: 12, phase: 2.4),
                with: .linearGradient(
                    Gradient(colors: [Color(red: 0.50, green: 0.70, blue: 0.44), lawnFar]),
                    startPoint: CGPoint(x: 0, y: horizon - 24), endPoint: CGPoint(x: 0, y: horizon + 4)
                )
            )

            // Lawn
            ctx.fill(
                Path(CGRect(x: 0, y: horizon, width: size.width, height: size.height - horizon)),
                with: .linearGradient(
                    Gradient(colors: [lawnFar, lawnNear]),
                    startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: h)
                )
            )

            // Street: sidewalk, then road
            let lotLine = horizon + Self.lotLine
            let gate = ox + Self.laneCenter(0, width: w)
            ctx.fill(Path(CGRect(x: 0, y: lotLine, width: size.width, height: 9)), with: .color(Color(red: 0.84, green: 0.83, blue: 0.79)))
            var joint: CGFloat = 0
            while joint < size.width {
                ctx.fill(Path(CGRect(x: joint, y: lotLine, width: 1, height: 9)), with: .color(Color(white: 0.70)))
                joint += 24
            }
            let roadTop = lotLine + 9
            let roadBottom = lotLine + 41
            ctx.fill(Path(CGRect(x: 0, y: roadTop, width: size.width, height: roadBottom - roadTop)), with: .color(Color(red: 0.36, green: 0.37, blue: 0.40)))
            var dash: CGFloat = 6
            while dash < size.width {
                ctx.fill(Path(CGRect(x: dash, y: (roadTop + roadBottom) / 2 - 1, width: 14, height: 2)), with: .color(Theme.sunflower.opacity(0.9)))
                dash += 28
            }
            if bikeLane {
                // green bike lane along the far side of the road
                let laneY = roadBottom - 11
                ctx.fill(Path(CGRect(x: 0, y: laneY, width: size.width, height: 9)), with: .color(Color(red: 0.36, green: 0.62, blue: 0.42)))
                ctx.fill(Path(CGRect(x: 0, y: laneY - 1, width: size.width, height: 1)), with: .color(.white.opacity(0.85)))
                var bikeX: CGFloat = 40
                while bikeX < size.width {
                    ctx.draw(Text(Image(systemName: "bicycle")).font(.system(size: 6.5, weight: .bold)).foregroundColor(.white), at: CGPoint(x: bikeX, y: laneY + 4.5))
                    bikeX += 120
                }
            }

            // crosswalk from the garden gate to the sidewalk
            for i in 0..<5 {
                ctx.fill(Path(CGRect(x: gate - 12, y: roadTop + 2 + CGFloat(i) * 6, width: 24, height: 3.4)), with: .color(.white.opacity(0.85)))
            }
            ctx.fill(Path(CGRect(x: 0, y: roadBottom, width: size.width, height: 3)), with: .color(Color(white: 0.78)))

            // Fence, with a gap for the gate
            let fenceBase = horizon + Self.fenceOffset
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

            // Grass tufts and wildflowers (none on the path)
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
    // At most one thing is selected: a plant, or a building on the street.
    @State private var selectedID: UUID? = nil
    @State private var selectedBuilding: VolunteerCategory? = nil
    @State private var selectedFixture: EcoTaskKind? = nil

    // Named space keeps drag translation stable while the plant moves.
    static let space = "yard"

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedID = nil
                    selectedBuilding = nil
                    selectedFixture = nil
                }

            StreetDecorations(level: appState.communityLevel, isNight: phase == .night)
                .frame(width: canvasSize.width, height: canvasSize.height)
                .allowsHitTesting(false)
                .zIndex(0.15)

            ForEach(EcoTaskKind.allCases, id: \.self) { kind in
                let tier = appState.upgradeTier(for: kind)
                if tier > 0 {
                    StreetFixture(
                        kind: kind,
                        tier: tier,
                        canvasSize: canvasSize,
                        phase: phase,
                        zoom: zoom,
                        isSelected: selectedFixture == kind,
                        isNew: appState.upgradeIsNew(kind),
                        onSelect: {
                            selectedID = nil
                            selectedBuilding = nil
                            selectedFixture = (selectedFixture == kind) ? nil : kind
                            appState.markUpgradeSeen(kind)
                        }
                    )
                    .zIndex(selectedFixture == kind ? 20 : 0.2)
                }
            }

            ForEach(VolunteerCategory.allCases) { category in
                BuildingLot(
                    category: category,
                    canvasSize: canvasSize,
                    phase: phase,
                    zoom: zoom,
                    isSelected: selectedBuilding == category,
                    onSelect: {
                        selectedID = nil
                        selectedFixture = nil
                        selectedBuilding = (selectedBuilding == category) ? nil : category
                    }
                )
                .zIndex(selectedBuilding == category ? 20 : 0.1)
            }

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
                        isNew: appState.newlyPlacedID == placed.id,
                        onSelect: {
                            selectedBuilding = nil
                            selectedFixture = nil
                            selectedID = (selectedID == placed.id) ? nil : placed.id
                            if appState.newlyPlacedID == placed.id { appState.newlyPlacedID = nil }
                        }
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
    let isNew: Bool
    let onSelect: () -> Void

    @GestureState private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var waterPulse = false
    @State private var showLevelUp = false
    @State private var showCantAfford = false
    @State private var swaying = false

    private var basePosition: CGPoint {
        CGPoint(x: placed.x * canvasSize.width, y: placed.y * canvasSize.height)
    }

    private var health: Double { placed.health(asOf: now) }
    private var isThirsty: Bool { health < 40 }

    // Nearer the bottom = closer = bigger.
    private var depthScale: CGFloat {
        let range = AppState.yardYRange
        let t = (placed.y - range.lowerBound) / (range.upperBound - range.lowerBound)
        return 0.74 + 0.44 * CGFloat(min(max(t, 0), 1))
    }

    private var spriteWidth: CGFloat { 112 * CGFloat(placed.scale) * depthScale }
    private var spriteHeight: CGFloat { spriteWidth * PlantSprite.designSize.height / PlantSprite.designSize.width }
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
        .background(alignment: .bottom) {
            if isNew {
                PulseRing(width: max(artSize.width * 1.1, 40))
                    .offset(y: -(groundInset - max(artSize.width * 1.1, 40) * 0.16))
            }
        }
        .overlay(alignment: .bottom) { touchArea }
        .overlay(alignment: .bottom) {
            if isNew && !isSelected {
                NewTag().offset(y: -(groundInset + artSize.height + 8))
            }
        }
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
                // undo the zoom so the card stays the same size
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
            // Different sway timing per plant.
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

    private var contactShadow: some View {
        let width = max(artSize.width * 0.85, 22)
        let height = width * 0.22
        return Ellipse()
            .fill(Color.black.opacity(isDragging ? 0.12 : 0.20))
            .frame(width: width * (isDragging ? 1.2 : 1), height: height)
            .blur(radius: 2)
            .offset(y: -(groundInset - height / 2) + (isDragging ? 6 : 0))
    }

    // Sized to the art, not the whole sprite frame.
    private var touchArea: some View {
        Color.clear
            .frame(width: max(44, artSize.width), height: max(44, artSize.height + groundInset))
            .contentShape(Rectangle())
            .accessibilityElement()
            .accessibilityLabel(accessibilityDescription)
            .accessibilityHint("Opens care options")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onSelect() }
            .gesture(
                // minimumDistance has to be 0 or a normal tap never counts and the care menu doesn't open
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
                            if isNew { appState.newlyPlacedID = nil }
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

    private var careColor: Color {
        switch item.kind {
        case .compostBin: return Theme.soil
        case .butterfly: return Theme.petal
        case .birdHouse: return Theme.sunflower
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

// MARK: - Community buildings

private extension VolunteerCategory {
    var lotX: CGFloat {
        switch self {
        case .animals: return 0.12
        case .library: return 0.31
        case .nature: return 0.50
        case .food: return 0.69
        case .homes: return 0.88
        }
    }
}

// Level comes from volunteer hours; goes quiet after 2 weeks without any.
private struct BuildingLot: View {
    @EnvironmentObject var appState: AppState
    let category: VolunteerCategory
    let canvasSize: CGSize
    let phase: DayPhase
    let zoom: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void

    private var hours: Double { appState.volunteerHours(in: category) }
    private var level: Int { VolunteerCategory.level(forHours: hours) }
    private var lively: Bool { appState.isLively(category) }

    private var width: CGFloat { min(canvasSize.width * 0.2, 210) }
    private var height: CGFloat { width * BuildingSprite.designSize.height / BuildingSprite.designSize.width }
    private var groundInset: CGFloat { BuildingSprite.groundInset * width / BuildingSprite.designSize.width }
    private var base: CGPoint {
        CGPoint(x: canvasSize.width * category.lotX, y: canvasSize.height * YardGround.horizon + YardGround.lotLine)
    }

    // Not as dark at night so lit windows still show.
    private var tint: Color {
        phase == .night ? phase.spriteTint.mix(with: .white, by: 0.35) : phase.spriteTint
    }

    var body: some View {
        BuildingSprite(category: category, level: level, lively: lively, isNight: phase == .night, size: width)
            .colorMultiply(tint)
            .allowsHitTesting(false)
            .overlay(alignment: .bottom) {
                Color.clear
                    .frame(width: width * 0.85, height: height * 0.8)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onSelect)
                    .accessibilityElement()
                    .accessibilityLabel(accessibilityDescription)
                    .accessibilityHint("Shows how to build it up")
                    .accessibilityAddTraits(.isButton)
            }
            .overlay(alignment: .bottom) {
                if isSelected {
                    // undo the zoom so the card stays the same size
                    callout
                        .fixedSize()
                        .scaleEffect(1 / zoom, anchor: .bottom)
                        .offset(y: -(height * 0.82))
                        .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
                }
            }
            .position(x: base.x, y: base.y - height / 2 + groundInset)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private var daysSinceVolunteering: Int? {
        guard let last = appState.lastVolunteered(in: category) else { return nil }
        return max(0, Int(appState.now.timeIntervalSince(last) / 86_400))
    }

    private var status: (text: String, icon: String, color: Color) {
        if level == 0 {
            return ("Volunteer 1 hour to break ground", "hammer.fill", Theme.stone)
        }
        if lively {
            let when: String
            switch daysSinceVolunteering ?? 0 {
            case 0: when = "today"
            case 1: when = "yesterday"
            case let days: when = "\(days) days ago"
            }
            return ("Lively, you volunteered \(when)", "sun.max.fill", Theme.moss)
        }
        return ("Quiet, nobody has volunteered in 2 weeks", "moon.zzz.fill", Theme.ember)
    }

    private var progressText: String {
        guard let remaining = VolunteerCategory.hoursToNextLevel(from: hours) else {
            return "Fully built! Keep volunteering to keep it lively."
        }
        return "\(formatHours(remaining)) more hrs to \(VolunteerCategory.stageNames[level + 1])"
    }

    private var accessibilityDescription: String {
        var parts = [category.buildingName, "level \(level + 1) of 4", VolunteerCategory.stageNames[level]]
        if level > 0 { parts.append(lively ? "lively" : "quiet") }
        return parts.joined(separator: ", ")
    }

    private var callout: some View {
        VStack(spacing: 6) {
            VStack(spacing: 1) {
                Text(category.buildingName)
                    .font(Theme.display(13, weight: .semibold))
                    .foregroundColor(Theme.bark)
                Text("Level \(level + 1) of 4 · \(VolunteerCategory.stageNames[level])")
                    .font(Theme.caption(11))
                    .foregroundColor(Theme.stone)
            }
            Label(status.text, systemImage: status.icon)
                .font(Theme.caption(11))
                .foregroundColor(status.color)
            Text(progressText)
                .font(Theme.body(10.5))
                .foregroundColor(Theme.stone)
            Button {
                appState.volunteerFocus = category
                appState.doGoodSegment = .volunteer
                appState.selectedTab = .doGood
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "hand.raised.fill")
                    Text("Find ways to help")
                }
                .font(Theme.caption())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Theme.moss))
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                .fill(.white.opacity(0.95))
        )
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
    }
}

// MARK: - New-item highlight

private struct PulseRing: View {
    let width: CGFloat
    @State private var expanding = false

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Theme.sunflower.opacity(0.28))
            Ellipse()
                .stroke(Theme.sunflower, lineWidth: 3)
                .scaleEffect(expanding ? 1.45 : 0.9)
                .opacity(expanding ? 0 : 0.95)
        }
        .frame(width: width, height: width * 0.32)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) { expanding = true }
        }
    }
}

private struct NewTag: View {
    @State private var bob = false

    var body: some View {
        Text("NEW")
            .font(Theme.caption(10))
            .fontWeight(.heavy)
            .foregroundColor(Theme.bark)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Theme.sunflower))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            .offset(y: bob ? -3 : 0)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { bob = true }
            }
    }
}

// MARK: - Street upgrades and decorations

private extension EcoTaskKind {
    var streetSlot: CGFloat {
        switch self {
        case .reusable: return 0.035
        case .travel: return 0.215
        case .recycle: return 0.405
        case .compost: return 0.595
        case .water: return 0.785
        case .donate: return 0.965
        }
    }
}

private struct StreetFixture: View {
    @EnvironmentObject var appState: AppState
    let kind: EcoTaskKind
    let tier: Int
    let canvasSize: CGSize
    let phase: DayPhase
    let zoom: CGFloat
    let isSelected: Bool
    let isNew: Bool
    let onSelect: () -> Void

    private let width: CGFloat = 54
    private var groundInset: CGFloat { UpgradeSprite.groundInset * width / UpgradeSprite.designSize.width }
    private var base: CGPoint {
        CGPoint(x: canvasSize.width * kind.streetSlot, y: canvasSize.height * YardGround.horizon + YardGround.lotLine + 8)
    }
    private var count: Int { appState.lifetimeCompletions[kind.rawValue] ?? 0 }

    var body: some View {
        UpgradeSprite(kind: kind, tier: tier, size: width)
            .colorMultiply(phase.spriteTint)
            .allowsHitTesting(false)
            .background(alignment: .bottom) {
                if isNew {
                    PulseRing(width: width * 1.2)
                        .offset(y: -(groundInset - width * 1.2 * 0.16))
                }
            }
            .overlay(alignment: .bottom) {
                Color.clear
                    .frame(width: max(44, width), height: max(44, width * 0.8))
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onSelect)
                    .accessibilityElement()
                    .accessibilityLabel("\(kind.upgradeNames[tier - 1]), from your eco habits")
                    .accessibilityAddTraits(.isButton)
            }
            .overlay(alignment: .bottom) {
                if isNew && !isSelected {
                    NewTag().offset(y: -(width * 0.9))
                }
            }
            .overlay(alignment: .bottom) {
                if isSelected {
                    callout
                        .fixedSize()
                        .scaleEffect(1 / zoom, anchor: .bottom)
                        .offset(y: -(width * 0.9))
                        .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
                }
            }
            .position(x: base.x, y: base.y - width / 2 + groundInset)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private var nextText: String {
        guard tier < EcoTaskKind.upgradeThresholds.count else { return "Fully upgraded" }
        let needed = EcoTaskKind.upgradeThresholds[tier] - count
        return "\(needed) more \(kind.habitPhrase) to get a \(kind.upgradeNames[tier])"
    }

    private var callout: some View {
        VStack(spacing: 6) {
            VStack(spacing: 1) {
                Text(kind.upgradeNames[tier - 1])
                    .font(Theme.display(13, weight: .semibold))
                    .foregroundColor(Theme.bark)
                Text("Built from your \(count) \(kind.habitPhrase)")
                    .font(Theme.caption(11))
                    .foregroundColor(Theme.stone)
            }
            Text(nextText)
                .font(Theme.body(10.5))
                .foregroundColor(Theme.stone)
            Button {
                appState.doGoodSegment = .habits
                appState.selectedTab = .doGood
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                    Text("Do it again")
                }
                .font(Theme.caption())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Theme.moss))
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                .fill(.white.opacity(0.95))
        )
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
    }
}

// Level 2: trees, 3: streetlights, 4: flags, 5: festival lights + balloons
private struct StreetDecorations: View {
    let level: Int
    let isNight: Bool

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let lotY = size.height * YardGround.horizon + YardGround.lotLine
            let curbY = lotY + 44

            if level >= 1 {
                // trees
                for fx in [0.215, 0.405, 0.595, 0.785] as [CGFloat] {
                    let x = w * fx
                    ctx.fill(Path(CGRect(x: x - 2, y: lotY - 26, width: 4, height: 26)), with: .color(Theme.trunk))
                    for (dx, dy, r, color) in [(0, -36, 13, Theme.leafDark), (-8, -29, 9, Theme.leaf), (8, -30, 9, Theme.leaf), (-2, -40, 7, Theme.leafLight)] as [(CGFloat, CGFloat, CGFloat, Color)] {
                        ctx.fill(Path(ellipseIn: CGRect(x: x + dx - r, y: lotY + dy - r, width: r * 2, height: r * 2)), with: .color(color))
                    }
                }
            }

            guard level >= 2 else { return }
            // streetlights
            let poleXs: [CGFloat] = (0..<6).map { w * (0.07 + 0.19 * CGFloat($0)) }.filter { $0 < w }
            let lampY = curbY - 50
            for x in poleXs {
                if isNight {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 22, y: lampY - 16, width: 44, height: 40)),
                             with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.88, blue: 0.5).opacity(0.55), .clear]),
                                                   center: CGPoint(x: x, y: lampY + 2), startRadius: 2, endRadius: 22))
                }
                ctx.fill(Path(CGRect(x: x - 1.2, y: lampY, width: 2.4, height: curbY - lampY)), with: .color(Color(white: 0.30)))
                ctx.fill(Path(roundedRect: CGRect(x: x - 5, y: lampY - 4, width: 10, height: 5), cornerRadius: 2), with: .color(Color(white: 0.25)))
                ctx.fill(Path(ellipseIn: CGRect(x: x - 3, y: lampY, width: 6, height: 4)),
                         with: .color(isNight ? Color(red: 1, green: 0.92, blue: 0.6) : Color(white: 0.92)))
            }

            guard level >= 3, poleXs.count > 1 else { return }
            // bunting
            let flagColors = [Theme.petal, Theme.sunflower, Theme.water, Theme.leafLight, Theme.lilac]
            for i in 0..<(poleXs.count - 1) {
                let a = CGPoint(x: poleXs[i], y: lampY - 3)
                let b = CGPoint(x: poleXs[i + 1], y: lampY - 3)
                let control = CGPoint(x: (a.x + b.x) / 2, y: a.y + 22)
                var line = Path()
                line.move(to: a)
                line.addQuadCurve(to: b, control: control)
                ctx.stroke(line, with: .color(Color(white: 0.35)), lineWidth: 0.8)

                let flags = Int((b.x - a.x) / 10)
                for f in 1..<max(flags, 2) {
                    let t = CGFloat(f) / CGFloat(flags)
                    let px = (1 - t) * (1 - t) * a.x + 2 * (1 - t) * t * control.x + t * t * b.x
                    let py = (1 - t) * (1 - t) * a.y + 2 * (1 - t) * t * control.y + t * t * b.y
                    var flag = Path()
                    flag.move(to: CGPoint(x: px - 3, y: py))
                    flag.addLine(to: CGPoint(x: px + 3, y: py))
                    flag.addLine(to: CGPoint(x: px, y: py + 6))
                    flag.closeSubpath()
                    ctx.fill(flag, with: .color(flagColors[(i + f) % flagColors.count]))

                    if level >= 4 {
                        // festival lights
                        let glow = isNight ? Color(red: 1, green: 0.9, blue: 0.55) : Color(red: 1, green: 0.95, blue: 0.8)
                        if isNight {
                            ctx.fill(Path(ellipseIn: CGRect(x: px + 3, y: py - 2.5, width: 6, height: 6)), with: .color(glow.opacity(0.35)))
                        }
                        ctx.fill(Path(ellipseIn: CGRect(x: px + 4.5, y: py - 1, width: 3, height: 3)), with: .color(glow))
                    }
                }
            }

            guard level >= 4 else { return }
            // balloons
            for (i, x) in poleXs.enumerated() where i % 2 == 0 {
                for (j, dx) in ([-6, 0, 6] as [CGFloat]).enumerated() {
                    let top = CGPoint(x: x + dx, y: lampY - 26 - CGFloat(j % 2) * 5)
                    var string = Path()
                    string.move(to: CGPoint(x: x, y: lampY - 4))
                    string.addLine(to: CGPoint(x: top.x, y: top.y + 5))
                    ctx.stroke(string, with: .color(Color(white: 0.4)), lineWidth: 0.6)
                    ctx.fill(Path(ellipseIn: CGRect(x: top.x - 4, y: top.y - 5, width: 8, height: 10)),
                             with: .color(flagColors[(i + j) % flagColors.count]))
                }
            }
        }
    }
}

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

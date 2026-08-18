import SwiftUI

struct GardenView: View {
    @EnvironmentObject var appState: AppState
    @State private var now = Date()
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    /// The scrollable yard is bigger than the screen in both directions —
    /// makes it feel like a real sprawling plot rather than a fixed tile.
    private let canvasHeight: CGFloat = 1500

    var body: some View {
        GeometryReader { screenGeo in
            let canvasWidth = max(screenGeo.size.width * 1.7, 620)

            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                ZStack(alignment: .top) {
                    YardBackground(width: canvasWidth, height: canvasHeight, now: now)

                    PlantLayer(canvasSize: CGSize(width: canvasWidth, height: canvasHeight), now: now)
                        .environmentObject(appState)

                    AmbientCritters(width: canvasWidth, height: canvasHeight)

                    if appState.placedItems.isEmpty {
                        EmptyYardCard()
                            .position(x: canvasWidth / 2, y: canvasHeight * 0.42)
                    }
                }
                .frame(width: canvasWidth, height: canvasHeight)
            }
            .ignoresSafeArea()
        }
        .overlay(alignment: .top) { topBar }
        .overlay(alignment: .bottom) { hintPill }
        .onReceive(ticker) { now = $0 }
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

            Spacer()

            if appState.streak > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill").foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.25))
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
        .padding(.top, 54)
    }

    private var hintPill: some View {
        Text("Tap a plant to water it • drag to move it • scroll to explore")
            .font(Theme.body(11.5))
            .foregroundColor(.white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(.black.opacity(0.35)))
            .padding(.bottom, 10)
    }
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

/// Small decorative critters that gently drift for a bit of life —
/// purely ambient, not interactive.
private struct AmbientCritters: View {
    let width: CGFloat
    let height: CGFloat

    private let critters: [(icon: String, x: CGFloat, y: CGFloat, color: Color)] = [
        ("ladybug.fill", 0.18, 0.55, Color(red: 0.78, green: 0.22, blue: 0.18)),
        ("ant.fill", 0.68, 0.62, Color(red: 0.75, green: 0.60, blue: 0.20)),
        ("bird.fill", 0.30, 0.20, Color(red: 0.35, green: 0.45, blue: 0.55))
    ]

    var body: some View {
        ForEach(0..<critters.count, id: \.self) { i in
            FlutteringCritter(icon: critters[i].icon, color: critters[i].color)
                .position(x: width * critters[i].x, y: height * critters[i].y)
        }
    }
}

private struct FlutteringCritter: View {
    let icon: String
    let color: Color
    @State private var offset: CGSize = .zero

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 13))
            .foregroundColor(color.opacity(0.8))
            .offset(offset)
            .onAppear {
                withAnimation(.easeInOut(duration: Double.random(in: 3...5)).repeatForever(autoreverses: true)) {
                    offset = CGSize(width: CGFloat.random(in: -14...14), height: CGFloat.random(in: -10...10))
                }
            }
    }
}

// MARK: - Background: sky, sun/moon, hills, clouds, texture

private struct YardBackground: View {
    let width: CGFloat
    let height: CGFloat
    let now: Date

    private var hour: Int { Calendar.current.component(.hour, from: now) }

    private var skyColors: [Color] {
        switch hour {
        case 5..<8:   return [Color(red: 0.98, green: 0.75, blue: 0.55), Color(red: 0.75, green: 0.80, blue: 0.70)] // dawn
        case 8..<17:  return [Color(red: 0.55, green: 0.78, blue: 0.92), Color(red: 0.80, green: 0.90, blue: 0.80)] // day
        case 17..<20: return [Color(red: 0.95, green: 0.55, blue: 0.45), Color(red: 0.55, green: 0.45, blue: 0.55)] // dusk
        default:      return [Color(red: 0.10, green: 0.12, blue: 0.25), Color(red: 0.20, green: 0.28, blue: 0.30)] // night
        }
    }

    private var isNight: Bool { hour >= 20 || hour < 5 }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: skyColors, startPoint: .top, endPoint: .bottom)

            CelestialBody(isNight: isNight)
                .position(x: width * 0.78, y: 100)

            DriftingClouds(width: width)

            // Rolling hills — layered ellipses for depth
            HillShape(baseY: height * 0.30, amplitude: 40, color: Theme.sage.opacity(0.55))
                .frame(width: width, height: height)
            HillShape(baseY: height * 0.34, amplitude: 55, color: Theme.moss.opacity(0.45))
                .frame(width: width, height: height)

            // Main grass field the plants live on
            Rectangle()
                .fill(LinearGradient(colors: [Theme.sage.opacity(0.55), Theme.moss.opacity(0.65)], startPoint: .top, endPoint: .bottom))
                .frame(width: width, height: height * 0.66)
                .position(x: width / 2, y: height * 0.34 + (height * 0.66) / 2)

            GrassTexture(width: width, yStart: height * 0.32, yEnd: height)

            WindingPath(width: width, yStart: height * 0.32, yEnd: height)
        }
        .frame(width: width, height: height)
        .clipped()
    }
}

private struct CelestialBody: View {
    let isNight: Bool
    var body: some View {
        ZStack {
            Circle().fill((isNight ? Color.white : Theme.sunflower).opacity(0.18)).frame(width: 90, height: 90)
            Circle().fill(isNight ? Color.white.opacity(0.9) : Theme.sunflower).frame(width: 48, height: 48)
            if isNight {
                Image(systemName: "moon.fill").font(.system(size: 20)).foregroundColor(Color(red: 0.85, green: 0.85, blue: 0.95))
            }
        }
    }
}

private struct DriftingClouds: View {
    let width: CGFloat
    @State private var drift: CGFloat = 0

    var body: some View {
        ZStack {
            CloudShape().position(x: width * 0.25 + drift, y: 70)
            CloudShape(scale: 0.7).position(x: width * 0.6 - drift * 0.6, y: 130)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                drift = 22
            }
        }
    }
}

private struct CloudShape: View {
    var scale: CGFloat = 1.0
    var body: some View {
        HStack(spacing: -14) {
            Circle().frame(width: 30 * scale)
            Circle().frame(width: 42 * scale).offset(y: -8 * scale)
            Circle().frame(width: 28 * scale)
        }
        .foregroundColor(.white.opacity(0.55))
    }
}

private struct HillShape: View {
    let baseY: CGFloat
    let amplitude: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { geo in
            Path { p in
                p.move(to: CGPoint(x: 0, y: baseY))
                p.addCurve(
                    to: CGPoint(x: geo.size.width, y: baseY - amplitude * 0.3),
                    control1: CGPoint(x: geo.size.width * 0.3, y: baseY - amplitude),
                    control2: CGPoint(x: geo.size.width * 0.7, y: baseY + amplitude * 0.6)
                )
                p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                p.addLine(to: CGPoint(x: 0, y: geo.size.height))
                p.closeSubpath()
            }
            .fill(color)
        }
    }
}

private struct WindingPath: View {
    let width: CGFloat
    let yStart: CGFloat
    let yEnd: CGFloat

    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: width * 0.5, y: yStart))
            p.addCurve(
                to: CGPoint(x: width * 0.35, y: (yStart + yEnd) / 2),
                control1: CGPoint(x: width * 0.65, y: yStart + (yEnd - yStart) * 0.2),
                control2: CGPoint(x: width * 0.2, y: yStart + (yEnd - yStart) * 0.35)
            )
            p.addCurve(
                to: CGPoint(x: width * 0.55, y: yEnd),
                control1: CGPoint(x: width * 0.5, y: (yStart + yEnd) / 2 + (yEnd - yStart) * 0.15),
                control2: CGPoint(x: width * 0.7, y: yEnd - (yEnd - yStart) * 0.1)
            )
        }
        .stroke(Theme.soil.opacity(0.28), style: StrokeStyle(lineWidth: 22, lineCap: .round))
    }
}

private struct GrassTexture: View {
    let width: CGFloat
    let yStart: CGFloat
    let yEnd: CGFloat

    private let positions: [(CGFloat, CGFloat)] = (0..<26).map { i in
        (CGFloat.random(in: 0.05...0.95), CGFloat.random(in: 0...1))
    }

    var body: some View {
        ForEach(0..<positions.count, id: \.self) { i in
            Image(systemName: "leaf.fill")
                .font(.system(size: CGFloat.random(in: 8...13)))
                .foregroundColor(Theme.moss.opacity(0.18))
                .rotationEffect(.degrees(Double.random(in: -30...30)))
                .position(x: width * positions[i].0, y: yStart + (yEnd - yStart) * positions[i].1)
        }
    }
}

// MARK: - Plants layer

private struct PlantLayer: View {
    @EnvironmentObject var appState: AppState
    let canvasSize: CGSize
    let now: Date
    @State private var selectedID: UUID? = nil

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
                        isSelected: selectedID == placed.id,
                        onSelect: { selectedID = (selectedID == placed.id) ? nil : placed.id }
                    )
                    .environmentObject(appState)
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }
}

private struct DraggablePlant: View {
    @EnvironmentObject var appState: AppState
    let placed: PlacedItem
    let item: GardenItem
    let canvasSize: CGSize
    let now: Date
    let isSelected: Bool
    let onSelect: () -> Void

    @GestureState private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var waterPulse = false
    @State private var showSparkles = false
    @State private var showCantAfford = false

    private var basePosition: CGPoint {
        CGPoint(x: placed.x * canvasSize.width, y: placed.y * canvasSize.height)
    }

    private var health: Double { placed.health(asOf: now) }
    private var isWilted: Bool { health < 40 }

    private var stageScale: Double {
        switch placed.stage {
        case 0: return 0.65
        case 1: return 0.82
        case 2: return 1.0
        default: return 1.18
        }
    }

    private var displayIcon: String {
        placed.stage == 0 ? "leaf.fill" : item.icon
    }

    var body: some View {
        VStack(spacing: 4) {
            if isSelected {
                Button(action: water) {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                        Text("Water")
                        Text("-\(appState.wateringCost)")
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .font(Theme.caption())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color(red: 0.30, green: 0.55, blue: 0.80)))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .zIndex(1)
                .transition(.scale.combined(with: .opacity))
                .alert("Not enough EcoCoins", isPresented: $showCantAfford) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Watering costs \(appState.wateringCost) coins. Complete tasks to earn more.")
                }
            }

            ZStack {
                Circle()
                    .fill(Color.black.opacity(isDragging ? 0.12 : 0.07))
                    .frame(width: 30, height: 30)
                    .offset(y: 18)

                Image(systemName: displayIcon)
                    .font(.system(size: 30))
                    .foregroundColor(isWilted ? item.color.opacity(0.35) : item.color)
                    .saturation(isWilted ? 0.3 : 1.0)
                    .rotationEffect(.degrees(placed.rotation + (isWilted ? 6 : 0) + (waterPulse ? -12 : 0)))
                    .scaleEffect(placed.scale * stageScale * (isDragging ? 1.15 : 1.0) * (waterPulse ? 1.28 : 1.0))
                    .animation(.interpolatingSpring(stiffness: 260, damping: 9), value: waterPulse)

                healthRing

                if showSparkles {
                    SparkleBurst()
                }
            }
        }
        .position(
            x: basePosition.x + dragOffset.width,
            y: basePosition.y + dragOffset.height
        )
        .shadow(color: .black.opacity(isDragging ? 0.15 : 0), radius: 7, y: 5)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .onChange(of: placed.stage) { _ in
            showSparkles = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { showSparkles = false }
        }
        .gesture(
            // minimumDistance 0 so a plain, no-movement tap still registers and calls onEnded —
            // otherwise stationary taps never satisfy a drag gesture and the water button never shows.
            DragGesture(minimumDistance: 0)
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

    private func water() {
        let success = appState.waterItem(id: placed.id)
        guard success else {
            showCantAfford = true
            return
        }
        waterPulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { waterPulse = false }
    }

    private var healthRing: some View {
        Circle()
            .trim(from: 0, to: health / 100)
            .stroke(healthColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: 42, height: 42)
            .opacity(isSelected || isWilted ? 1 : 0.55)
    }

    private var healthColor: Color {
        if health > 65 { return Theme.moss }
        if health > 35 { return Theme.sunflower }
        return Color(red: 0.75, green: 0.30, blue: 0.25)
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

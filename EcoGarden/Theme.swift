import SwiftUI

// App colors, fonts and shared styles.
enum Theme {

    // MARK: - Palette

    // Forest green is the main color. Gold is only for progress bars and coins.
    static let forest = Color(red: 0.12, green: 0.30, blue: 0.21)
    static let moss = forest
    static let sage = Color(red: 0.60, green: 0.71, blue: 0.56)
    static let soil = Color(red: 0.42, green: 0.32, blue: 0.22)
    static let sunflower = Color(red: 0.89, green: 0.70, blue: 0.24)
    // screen background
    static let skyWash = Color(red: 0.914, green: 0.933, blue: 0.894)
    static let bark = Color(red: 0.12, green: 0.15, blue: 0.13)
    static let stone = Color(red: 0.37, green: 0.42, blue: 0.38)
    // Card base. Has to be lighter than the background or the green cards disappear.
    static let card = Color(red: 0.982, green: 0.986, blue: 0.972)
    static let ember = Color(red: 0.85, green: 0.45, blue: 0.20)

    // MARK: - Garden art colors

    static let leafLight = Color(red: 0.52, green: 0.74, blue: 0.36)
    static let leaf = Color(red: 0.31, green: 0.57, blue: 0.28)
    static let leafDark = Color(red: 0.17, green: 0.40, blue: 0.22)
    static let wilt = Color(red: 0.68, green: 0.58, blue: 0.30)
    static let trunk = Color(red: 0.47, green: 0.33, blue: 0.20)
    static let trunkDark = Color(red: 0.32, green: 0.22, blue: 0.14)
    static let wood = Color(red: 0.69, green: 0.51, blue: 0.32)
    static let woodDark = Color(red: 0.45, green: 0.31, blue: 0.19)
    static let compost = Color(red: 0.22, green: 0.16, blue: 0.11)
    static let petal = Color(red: 0.92, green: 0.42, blue: 0.50)
    static let petalLight = Color(red: 0.98, green: 0.80, blue: 0.84)
    static let lilac = Color(red: 0.66, green: 0.52, blue: 0.86)
    static let berry = Color(red: 0.80, green: 0.20, blue: 0.24)
    static let water = Color(red: 0.36, green: 0.63, blue: 0.86)

    // MARK: - Fonts

    // titles
    static func heading(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }

    // Bold looked too heavy, so anything bolder than semibold gets capped.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        let calm: Font.Weight = [.bold, .heavy, .black].contains(weight) ? .semibold : weight
        return .system(size: size, weight: calm)
    }

    static func body(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium)
    }

    // MARK: - Corner radius

    static let cardRadius: CGFloat = 18
    static let controlRadius: CGFloat = 12
}

// MARK: - Reusable card style

// Cards get a light tint of their habit/category color (sage if there isn't one).
struct EcoCard: ViewModifier {
    var tint: Color = Theme.sage

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                            .fill(tint.opacity(0.09))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(tint.opacity(0.2), lineWidth: 1)
            )
    }
}

// Green header at the top of each tab.
extension View {
    func greenHeader() -> some View {
        padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            // tall so you still see green when you pull down past the top
            .background(alignment: .bottom) { Theme.forest.frame(height: 2000) }
    }

    // needed so the status bar text is white on the green
    func greenNavigationBar() -> some View {
        toolbarBackground(Theme.forest, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// On iOS 26 toolbar items get a glass bubble behind them. Looked bad on the green, so this hides it.
struct HeaderToolbarItem<Content: View>: ToolbarContent {
    let placement: ToolbarItemPlacement
    @ViewBuilder let content: () -> Content

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if #available(iOS 26, *) {
            ToolbarItem(placement: placement, content: content)
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: placement, content: content)
        }
    }
}

struct ScreenBackground: View {
    var body: some View {
        Theme.skyWash.ignoresSafeArea()
    }
}

extension View {
    func ecoCard(tint: Color = Theme.sage) -> some View { modifier(EcoCard(tint: tint)) }
}

// MARK: - Icon tile

// Rounded square icon used all over the app.
struct IconTile: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 44
    var muted = false

    var body: some View {
        let color = muted ? Theme.stone : tint
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(color.opacity(0.16))
            Image(systemName: systemName)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Shared controls

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.display(17))
            .foregroundColor(Theme.bark)
            .padding(.leading, 2)
    }
}

struct EcoField: View {
    let label: String
    let prompt: String
    @Binding var text: String
    var isSecure = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(Theme.caption(11))
                .foregroundColor(Theme.stone)
                .tracking(0.5)

            Group {
                if isSecure {
                    SecureField(prompt, text: $text)
                } else {
                    TextField(prompt, text: $text)
                }
            }
            .focused($isFocused)
            .font(Theme.body(16))
            .foregroundColor(Theme.bark)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .fill(Theme.skyWash.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .strokeBorder(isFocused ? Theme.moss : Theme.sage.opacity(0.35), lineWidth: isFocused ? 1.5 : 1)
            )
        }
    }
}

struct EcoPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .fill(Theme.moss)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Coin badge

struct CoinBadge: View {
    let amount: Int
    // true when it's on the green header
    var onDark = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Theme.sunflower)
                .frame(width: 16, height: 16)
                .overlay(
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.forest)
                )
            Text("\(amount)")
                .font(Theme.display(15))
                .foregroundColor(onDark ? .white : Theme.bark)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(onDark ? Color.white.opacity(0.14) : Theme.card))
        // without this the toolbar cuts the number off
        .fixedSize()
    }
}

import SwiftUI

/// A deliberate, specific design language for EcoGarden.
/// Avoid Color.green / Color.blue everywhere — those are the "default AI app" tell.
enum Theme {

    // MARK: - Palette (named + intentional, not system defaults)

    /// Deep moss — primary brand color, used for headers & key actions
    static let moss = Color(red: 0.20, green: 0.34, blue: 0.24)
    /// Soft sage — secondary green, used for cards & fills
    static let sage = Color(red: 0.60, green: 0.71, blue: 0.56)
    /// Warm soil — brown accent for earthy elements (compost, wood, dirt)
    static let soil = Color(red: 0.42, green: 0.32, blue: 0.22)
    /// Sunflower — the ONE bright accent, used sparingly for coins/rewards only
    static let sunflower = Color(red: 0.91, green: 0.72, blue: 0.30)
    /// Sky wash — pale background tint, not pure white/cream
    static let skyWash = Color(red: 0.93, green: 0.96, blue: 0.92)
    /// Bark — near-black text color, warmer than pure black
    static let bark = Color(red: 0.14, green: 0.13, blue: 0.10)
    /// Muted stone — secondary text
    static let stone = Color(red: 0.45, green: 0.44, blue: 0.40)
    /// Card — a warm off-white that every card, tile and text field sits on
    static let card = Color(red: 0.995, green: 0.99, blue: 0.975)
    /// Ember — streak flames and error messages
    static let ember = Color(red: 0.85, green: 0.45, blue: 0.20)

    // MARK: - Garden art tones (used by the drawn plants & scenery)

    static let leafLight = Color(red: 0.52, green: 0.74, blue: 0.36)
    static let leaf = Color(red: 0.31, green: 0.57, blue: 0.28)
    static let leafDark = Color(red: 0.17, green: 0.40, blue: 0.22)
    /// What foliage fades toward as a plant dries out
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

    // MARK: - Type roles

    /// Headlines: rounded system font gives a friendly, crafted feel
    /// without needing to bundle custom font files.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func body(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    // MARK: - Shape language

    static let cardRadius: CGFloat = 18
    static let controlRadius: CGFloat = 12
}

// MARK: - Reusable card style

struct EcoCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(Theme.sage.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Theme.bark.opacity(0.05), radius: 8, y: 3)
    }
}

extension View {
    func ecoCard() -> some View { modifier(EcoCard()) }
}

// MARK: - Shared controls, so every screen's headings, fields and buttons match

/// The small all-caps heading above a group of cards.
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(Theme.caption(11))
            .foregroundColor(Theme.stone)
            .tracking(1)
            .padding(.leading, 2)
    }
}

/// A labelled text field. Pass `isSecure` for passwords.
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

/// The one big green button per screen.
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

// MARK: - Coin badge, used consistently in nav bars instead of a plain Label

struct CoinBadge: View {
    let amount: Int

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Theme.sunflower)
                .frame(width: 18, height: 18)
                .overlay(
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.moss)
                )
            Text("\(amount)")
                .font(Theme.display(15, weight: .semibold))
                .foregroundColor(Theme.bark)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.sunflower.opacity(0.18)))
    }
}

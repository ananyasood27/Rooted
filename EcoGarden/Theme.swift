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
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(Theme.sage.opacity(0.25), lineWidth: 1)
            )
    }
}

extension View {
    func ecoCard() -> some View { modifier(EcoCard()) }
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

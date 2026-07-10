import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Design tokens

/// Konnector design system — 4pt grid, brand palette, fixed button radii.
enum K {
    static let unit: CGFloat = 4

    // MARK: Spacing

    enum Spacing {
        static let xs: CGFloat = unit          // 4
        static let sm: CGFloat = unit * 2      // 8
        static let md: CGFloat = unit * 3      // 12
        static let lg: CGFloat = unit * 4      // 16
        static let xl: CGFloat = unit * 5      // 20
        static let xxl: CGFloat = unit * 6     // 24
        static let xxxl: CGFloat = unit * 8    // 32
    }

    // MARK: Button radius (fixed set)

    /// Only these two corner radii may be used on rectangular buttons.
    enum ButtonRadius {
        static let standard: CGFloat = Spacing.lg    // 16
        static let prominent: CGFloat = unit * 7   // 28
    }

    // MARK: Surface radius

    enum Radius {
        static let sm: CGFloat = Spacing.md      // 12 — nested tiles, inputs
        static let md: CGFloat = Spacing.lg      // 16 — cards
        static let lg: CGFloat = Spacing.xl      // 20 — large surfaces
        static let xl: CGFloat = Spacing.xxl     // 24 — hero panels

        static var card: CGFloat { md }
        static var tile: CGFloat { sm }
    }

    // MARK: Size

    enum Size {
        enum Button {
            static let sm: CGFloat = 36
            static let md: CGFloat = 44
            static let lg: CGFloat = 52
        }

        enum Avatar {
            static let xs: CGFloat = 32
            static let sm: CGFloat = 44
            static let md: CGFloat = 56
            static let lg: CGFloat = 72
        }

        enum ScoreBadge {
            static let compact: CGFloat = 30
            static let regular: CGFloat = 40
        }

        enum Icon {
            static let sm: CGFloat = 16
            static let md: CGFloat = 20
            static let lg: CGFloat = 28
        }
    }

    // MARK: Stroke & shadow

    enum Stroke {
        static let hairline: CGFloat = 1
        static let regular: CGFloat = 2
    }

    enum Shadow {
        static let softRadius: CGFloat = 8
        static let softY: CGFloat = 2
        static let softOpacity: Double = 0.08
    }

    // MARK: Layout

    enum Layout {
        static let screenHorizontal = Spacing.xl
        static let screenVertical = Spacing.xxl
        static let sectionSpacing = Spacing.xxl
        static let cardPadding = Spacing.lg
        static let stackSpacing = Spacing.md
    }

    // MARK: Typography

    enum Typography {
        static let sectionTitle = Font.subheadline.weight(.semibold)
        static let buttonLarge = Font.body.weight(.semibold)
        static let buttonMedium = Font.subheadline.weight(.semibold)
        static let buttonSmall = Font.caption.weight(.semibold)
        static let badgeMini = Font.caption2.weight(.semibold)
        static let badgeCompact = Font.caption.weight(.semibold)
        static let badgeRegular = Font.subheadline.weight(.semibold)
    }

    // MARK: Brand colors

    enum Color {
        // MARK: Palette (asset catalog)

        /// Navy — headers, navigation, structural accents. `#0B1F3A`
        static let navy = SwiftUI.Color("KonnectorPrimary")
        /// Bright blue — links, highlights, connection cues. `#1E88E5`
        static let blue = SwiftUI.Color("KonnectorSecondary")
        /// Orange — primary CTAs and active states. `#F97316`
        static let orange = SwiftUI.Color("KonnectorOrange")
        /// Green — success, growth, positive metrics. `#16A34A`
        static let green = SwiftUI.Color("KonnectorGreen")

        // MARK: Semantic roles

        /// Interactive accent — links, highlights, app tint.
        static let primary = blue
        /// Structural brand — headers, secondary actions, low scores.
        static let secondary = navy
        /// Call-to-action and active emphasis.
        static let accent = orange
        /// Positive / growth indicators.
        static let success = green

        static let primarySoft = primary.opacity(0.12)
        static let secondarySoft = secondary.opacity(0.12)
        static let accentSoft = accent.opacity(0.12)
        static let successSoft = success.opacity(0.12)
        static let primaryMuted = primary.opacity(0.16)
        static let secondaryMuted = secondary.opacity(0.16)
        static let accentMuted = accent.opacity(0.16)

        // MARK: Surfaces & neutrals

        /// Page background — white in light mode.
        static let screenBackground = adaptive(
            light: UIColor(red: 1, green: 1, blue: 1, alpha: 1),
            dark: .systemBackground
        )
        /// Subtle panels, cards, table rows. `#F6F8FA`
        static let surface = adaptive(
            light: UIColor(red: 0.965, green: 0.973, blue: 0.980, alpha: 1),
            dark: .secondarySystemBackground
        )
        static let cardBackground = adaptive(
            light: UIColor(red: 1, green: 1, blue: 1, alpha: 1),
            dark: .secondarySystemGroupedBackground
        )
        static let tileBackground = surface
        static let tileSelectedBackground = adaptive(
            light: UIColor(red: 0.929, green: 0.937, blue: 0.949, alpha: 1),
            dark: .tertiarySystemGroupedBackground
        )

        /// Main text. `#111827`
        static let textPrimary = adaptive(
            light: UIColor(red: 0.067, green: 0.094, blue: 0.153, alpha: 1),
            dark: .label
        )
        /// Secondary text. `#4B5563`
        static let textSecondary = adaptive(
            light: UIColor(red: 0.294, green: 0.333, blue: 0.388, alpha: 1),
            dark: .secondaryLabel
        )
        /// Muted text. `#6B7280`
        static let textMuted = adaptive(
            light: UIColor(red: 0.420, green: 0.447, blue: 0.502, alpha: 1),
            dark: .tertiaryLabel
        )
        /// Borders / dividers. `#E5E7EB`
        static let border = adaptive(
            light: UIColor(red: 0.898, green: 0.906, blue: 0.922, alpha: 1),
            dark: .separator
        )

        /// Interpolates navy → blue. `amount` 0 = secondary (navy), 1 = primary (blue).
        static func blend(amount: Double) -> SwiftUI.Color {
            blend(from: secondary, to: primary, amount: amount)
        }

        /// Distinct per-badge accents so tags read as colorful categories, not brand blends.
        static let badgeFriend = blue
        static let badgeColleague = success
        static let badgeClient = orange
        static let badgeMentor = SwiftUI.Color(red: 0.49, green: 0.32, blue: 0.86)
        static let badgeFamily = SwiftUI.Color(red: 0.86, green: 0.28, blue: 0.48)

        static func blend(from: SwiftUI.Color, to: SwiftUI.Color, amount: Double) -> SwiftUI.Color {
            let clamped = min(max(amount, 0), 1)

            #if canImport(UIKit)
            let fromUIColor = UIColor(from)
            let toUIColor = UIColor(to)
            var fromRed: CGFloat = 0
            var fromGreen: CGFloat = 0
            var fromBlue: CGFloat = 0
            var fromAlpha: CGFloat = 0
            var toRed: CGFloat = 0
            var toGreen: CGFloat = 0
            var toBlue: CGFloat = 0
            var toAlpha: CGFloat = 0

            fromUIColor.getRed(&fromRed, green: &fromGreen, blue: &fromBlue, alpha: &fromAlpha)
            toUIColor.getRed(&toRed, green: &toGreen, blue: &toBlue, alpha: &toAlpha)

            return SwiftUI.Color(
                red: Double(fromRed + (toRed - fromRed) * clamped),
                green: Double(fromGreen + (toGreen - fromGreen) * clamped),
                blue: Double(fromBlue + (toBlue - fromBlue) * clamped),
                opacity: Double(fromAlpha + (toAlpha - fromAlpha) * clamped)
            )
            #else
            return clamped < 0.5 ? from : to
            #endif
        }

        #if canImport(UIKit)
        private static func adaptive(light: UIColor, dark: UIColor) -> SwiftUI.Color {
            SwiftUI.Color(
                uiColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark ? dark : light
                }
            )
        }
        #else
        private static func adaptive(light: SwiftUI.Color, dark: SwiftUI.Color) -> SwiftUI.Color {
            light
        }
        #endif
    }
}

// MARK: - Badge tint palette

/// Distinct badge colors for built-in and custom contact tags.
enum BadgeTintPalette: String, CaseIterable, Identifiable, Sendable {
    case primary
    case secondary
    case sky
    case slate
    case mist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .primary: "Blue"
        case .secondary: "Green"
        case .sky: "Violet"
        case .slate: "Orange"
        case .mist: "Rose"
        }
    }

    var color: Color {
        switch self {
        case .primary: K.Color.badgeFriend
        case .secondary: K.Color.badgeColleague
        case .sky: K.Color.badgeMentor
        case .slate: K.Color.badgeClient
        case .mist: K.Color.badgeFamily
        }
    }
}

// MARK: - Button corner preset

enum KButtonCorner {
    case standard
    case prominent

    var radius: CGFloat {
        switch self {
        case .standard: K.ButtonRadius.standard
        case .prominent: K.ButtonRadius.prominent
        }
    }
}

// MARK: - Shapes

extension RoundedRectangle {
    static func k(_ radius: CGFloat, style: RoundedCornerStyle = .continuous) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: style)
    }

    static func kButton(_ corner: KButtonCorner) -> RoundedRectangle {
        .k(corner.radius)
    }
}

// MARK: - Liquid Glass helpers

enum KGlass {
    static func interactive(tint: Color? = nil) -> Glass {
        if let tint {
            return .regular.tint(tint).interactive()
        }
        return .regular.interactive()
    }
}

extension View {
    func kButtonGlass(tint: Color? = nil, cornerRadius: CGFloat, isEnabled: Bool = true) -> some View {
        glassEffect(
            isEnabled ? KGlass.interactive(tint: tint) : .identity,
            in: .rect(cornerRadius: cornerRadius)
        )
    }

    func kCapsuleGlass(tint: Color? = nil, isEnabled: Bool = true) -> some View {
        glassEffect(
            isEnabled ? KGlass.interactive(tint: tint) : .identity,
            in: .capsule
        )
    }

    func kCircleGlass(tint: Color? = nil, isEnabled: Bool = true) -> some View {
        glassEffect(
            isEnabled ? KGlass.interactive(tint: tint) : .identity,
            in: .circle
        )
    }
}

// MARK: - View modifiers

extension View {
    func kScreenPadding() -> some View {
        padding(.horizontal, K.Layout.screenHorizontal)
            .padding(.vertical, K.Layout.screenVertical)
    }

    func kCardSurface(
        contentPadding: CGFloat = K.Layout.cardPadding,
        radius: CGFloat = K.Radius.card
    ) -> some View {
        padding(contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(K.Color.cardBackground, in: RoundedRectangle.k(radius))
    }

    func kTileSurface(
        isSelected: Bool,
        selectedFill: SwiftUI.Color = K.Color.tileSelectedBackground,
        unselectedFill: SwiftUI.Color = K.Color.tileBackground,
        selectedStroke: SwiftUI.Color = K.Color.accent,
        radius: CGFloat = K.Radius.tile
    ) -> some View {
        background(
            isSelected ? selectedFill : unselectedFill,
            in: RoundedRectangle.k(radius)
        )
        .overlay {
            RoundedRectangle.k(radius)
                .strokeBorder(isSelected ? selectedStroke : .clear, lineWidth: K.Stroke.regular)
        }
    }

    func kSoftShadow() -> some View {
        shadow(
            color: .black.opacity(K.Shadow.softOpacity),
            radius: K.Shadow.softRadius,
            y: K.Shadow.softY
        )
    }

    func kContactCard() -> some View {
        padding(.horizontal, K.Spacing.lg)
        .padding(.vertical, K.Spacing.md)
        .background(K.Color.cardBackground, in: RoundedRectangle.k(K.Radius.xl))
        .overlay {
            RoundedRectangle.k(K.Radius.xl)
                .strokeBorder(K.Color.border, lineWidth: K.Stroke.hairline)
        }
    }
}

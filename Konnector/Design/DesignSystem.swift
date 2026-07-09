import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Design tokens

/// Konnector design system — 4pt grid, two brand colors, fixed button radii.
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
        static let badgeCompact = Font.caption.weight(.semibold)
        static let badgeRegular = Font.subheadline.weight(.semibold)
    }

    // MARK: Brand colors

    enum Color {
        /// Main brand color — primary actions, links, active states.
        static let primary = SwiftUI.Color("KonnectorPrimary")
        /// Supporting brand color — secondary actions, structure, low scores.
        static let secondary = SwiftUI.Color("KonnectorSecondary")

        static let primarySoft = primary.opacity(0.12)
        static let secondarySoft = secondary.opacity(0.12)
        static let primaryMuted = primary.opacity(0.16)
        static let secondaryMuted = secondary.opacity(0.16)

        static let screenBackground = SwiftUI.Color(.systemGroupedBackground)
        static let cardBackground = SwiftUI.Color(.systemBackground)
        static let tileBackground = SwiftUI.Color(.secondarySystemGroupedBackground)
        static let tileSelectedBackground = SwiftUI.Color(.tertiarySystemGroupedBackground)

        /// Interpolates between the two brand colors. `amount` 0 = secondary, 1 = primary.
        static func blend(amount: Double) -> SwiftUI.Color {
            blend(from: secondary, to: primary, amount: amount)
        }

        /// Per-badge accents derived from the Konnector primary/secondary blend curve.
        static let badgeFriend = primary
        static let badgeColleague = secondary
        static let badgeClient = blend(amount: 0.28)
        static let badgeMentor = blend(amount: 0.76)
        static let badgeFamily = blend(amount: 0.52)

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
    }
}

// MARK: - Badge tint palette

/// Brand-derived badge colors for built-in and custom contact tags.
enum BadgeTintPalette: String, CaseIterable, Identifiable, Sendable {
    case primary
    case secondary
    case sky
    case slate
    case mist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .primary: "Vibrant"
        case .secondary: "Slate"
        case .sky: "Sky"
        case .slate: "Deep Slate"
        case .mist: "Mist"
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
        selectedStroke: SwiftUI.Color = K.Color.secondary,
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
                .strokeBorder(K.Color.secondary.opacity(0.14), lineWidth: K.Stroke.hairline)
        }
    }
}

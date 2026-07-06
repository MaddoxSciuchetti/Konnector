import SwiftUI

enum KButtonSize {
    case small
    case medium
    case large

    var height: CGFloat {
        switch self {
        case .small: K.Size.Button.sm
        case .medium: K.Size.Button.md
        case .large: K.Size.Button.lg
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: K.Spacing.md
        case .medium: K.Spacing.lg
        case .large: K.Spacing.xl
        }
    }

    var font: Font {
        switch self {
        case .small: K.Typography.buttonSmall
        case .medium: K.Typography.buttonMedium
        case .large: K.Typography.buttonLarge
        }
    }
}

struct KPrimaryButtonStyle: ButtonStyle {
    var size: KButtonSize = .large
    var corner: KButtonCorner = .prominent
    var expands: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundStyle(.white)
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: expands ? .infinity : nil)
            .frame(height: size.height)
            .background(
                K.Color.primary.opacity(configuration.isPressed ? 0.88 : 1),
                in: RoundedRectangle.kButton(corner)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct KSecondaryButtonStyle: ButtonStyle {
    var size: KButtonSize = .large
    var corner: KButtonCorner = .standard
    var expands: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundStyle(K.Color.secondary)
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: expands ? .infinity : nil)
            .frame(height: size.height)
            .background(
                configuration.isPressed ? K.Color.secondaryMuted : K.Color.secondarySoft,
                in: RoundedRectangle.kButton(corner)
            )
            .overlay {
                RoundedRectangle.kButton(corner)
                    .strokeBorder(K.Color.secondary.opacity(0.22), lineWidth: K.Stroke.hairline)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct KTertiaryButtonStyle: ButtonStyle {
    var size: KButtonSize = .medium
    var corner: KButtonCorner = .standard
    var expands: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundStyle(.primary)
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: expands ? .infinity : nil)
            .frame(height: size.height)
            .background(
                configuration.isPressed ? K.Color.tileSelectedBackground : K.Color.tileBackground,
                in: RoundedRectangle.kButton(corner)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct KSelectionTileButtonStyle: ButtonStyle {
    var isSelected: Bool
    var tint: Color
    var radius: CGFloat = K.Radius.tile

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.horizontal, K.Spacing.md)
            .padding(.vertical, K.Spacing.md)
            .background(
                isSelected ? tint.opacity(0.16) : K.Color.tileBackground,
                in: RoundedRectangle.k(radius)
            )
            .overlay {
                RoundedRectangle.k(radius)
                    .strokeBorder(isSelected ? tint : .clear, lineWidth: K.Stroke.regular)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == KPrimaryButtonStyle {
    static var kPrimary: KPrimaryButtonStyle { KPrimaryButtonStyle() }
    static func kPrimary(
        size: KButtonSize = .large,
        corner: KButtonCorner = .prominent,
        expands: Bool = true
    ) -> KPrimaryButtonStyle {
        KPrimaryButtonStyle(size: size, corner: corner, expands: expands)
    }
}

extension ButtonStyle where Self == KSecondaryButtonStyle {
    static var kSecondary: KSecondaryButtonStyle { KSecondaryButtonStyle() }
    static func kSecondary(
        size: KButtonSize = .large,
        corner: KButtonCorner = .standard,
        expands: Bool = true
    ) -> KSecondaryButtonStyle {
        KSecondaryButtonStyle(size: size, corner: corner, expands: expands)
    }
}

extension ButtonStyle where Self == KTertiaryButtonStyle {
    static var kTertiary: KTertiaryButtonStyle { KTertiaryButtonStyle() }
    static func kTertiary(
        size: KButtonSize = .medium,
        corner: KButtonCorner = .standard,
        expands: Bool = false
    ) -> KTertiaryButtonStyle {
        KTertiaryButtonStyle(size: size, corner: corner, expands: expands)
    }
}

extension ButtonStyle where Self == KSelectionTileButtonStyle {
    static func kSelectionTile(
        isSelected: Bool,
        tint: Color,
        radius: CGFloat = K.Radius.tile
    ) -> KSelectionTileButtonStyle {
        KSelectionTileButtonStyle(isSelected: isSelected, tint: tint, radius: radius)
    }
}

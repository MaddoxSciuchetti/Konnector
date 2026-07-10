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
    @Environment(\.isEnabled) private var isEnabled

    var size: KButtonSize = .large
    var corner: KButtonCorner = .prominent
    var expands: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.76))
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: expands ? .infinity : nil)
            .frame(height: size.height)
            .kButtonGlass(tint: K.Color.accent, cornerRadius: corner.radius, isEnabled: isEnabled)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct KSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var size: KButtonSize = .large
    var corner: KButtonCorner = .standard
    var expands: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.76))
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: expands ? .infinity : nil)
            .frame(height: size.height)
            .kButtonGlass(tint: K.Color.secondary, cornerRadius: corner.radius, isEnabled: isEnabled)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct KTertiaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var size: KButtonSize = .medium
    var corner: KButtonCorner = .standard
    var expands: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundStyle(.primary.opacity(isEnabled ? 1 : 0.76))
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: expands ? .infinity : nil)
            .frame(height: size.height)
            .kButtonGlass(cornerRadius: corner.radius, isEnabled: isEnabled)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct KSelectionTileButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var isSelected: Bool
    var tint: Color
    var radius: CGFloat = K.Radius.tile

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.horizontal, K.Spacing.md)
            .padding(.vertical, K.Spacing.md)
            .kButtonGlass(
                tint: isSelected ? tint : nil,
                cornerRadius: radius,
                isEnabled: isEnabled
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct KGlassCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var tint: Color
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? .white.opacity(isEnabled ? 1 : 0.76) : tint.opacity(isEnabled ? 1 : 0.76))
            .kCapsuleGlass(tint: isSelected ? tint : nil, isEnabled: isEnabled)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct KGlassCircleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var tint: Color
    var isSelected: Bool
    var size: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .foregroundStyle(isSelected ? .white.opacity(isEnabled ? 1 : 0.76) : tint.opacity(isEnabled ? 1 : 0.76))
            .kCircleGlass(tint: isSelected ? tint : nil, isEnabled: isEnabled)
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

extension ButtonStyle where Self == KGlassCapsuleButtonStyle {
    static func kGlassCapsule(tint: Color, isSelected: Bool = false) -> KGlassCapsuleButtonStyle {
        KGlassCapsuleButtonStyle(tint: tint, isSelected: isSelected)
    }
}

extension ButtonStyle where Self == KGlassCircleButtonStyle {
    static func kGlassCircle(tint: Color, isSelected: Bool = false, size: CGFloat = 44) -> KGlassCircleButtonStyle {
        KGlassCircleButtonStyle(tint: tint, isSelected: isSelected, size: size)
    }
}

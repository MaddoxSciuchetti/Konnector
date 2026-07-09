import Foundation
import SwiftData
import SwiftUI

@Model
final class BadgeDefinition {
    @Attribute(.unique) var identifier: String
    var title: String
    var systemImage: String
    var usesPrimaryTint: Bool = true
    var tintPaletteKey: String = BadgeTintPalette.primary.rawValue
    var isCustom: Bool = false
    var createdAt: Date
    var sortOrder: Int

    init(
        identifier: String,
        title: String,
        systemImage: String,
        usesPrimaryTint: Bool = true,
        tintPaletteKey: String = BadgeTintPalette.primary.rawValue,
        isCustom: Bool = false,
        createdAt: Date = .now,
        sortOrder: Int = 0
    ) {
        self.identifier = identifier
        self.title = title
        self.systemImage = systemImage
        self.usesPrimaryTint = usesPrimaryTint
        self.tintPaletteKey = tintPaletteKey
        self.isCustom = isCustom
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }

    var tintPalette: BadgeTintPalette {
        if let builtin = ContactBadge(rawValue: identifier) {
            return builtin.tintPalette
        }
        return BadgeTintPalette(rawValue: tintPaletteKey)
            ?? (usesPrimaryTint ? .primary : .secondary)
    }

    var tint: Color {
        tintPalette.color
    }
}

enum BadgeCatalogService {
    static func ensureDefaults(in context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<BadgeDefinition>())
        backfillLegacyBadgeFields(existing)

        guard existing.isEmpty else { return }

        for (index, builtin) in ContactBadge.allCases.enumerated() {
            context.insert(
                BadgeDefinition(
                    identifier: builtin.rawValue,
                    title: builtin.title,
                    systemImage: builtin.systemImage,
                    usesPrimaryTint: builtin.usesPrimaryTint,
                    tintPaletteKey: builtin.tintPalette.rawValue,
                    isCustom: false,
                    sortOrder: index
                )
            )
        }
    }

    private static func backfillLegacyBadgeFields(_ badges: [BadgeDefinition]) {
        for badge in badges where badge.tintPaletteKey.isEmpty {
            if let builtin = ContactBadge(rawValue: badge.identifier) {
                badge.tintPaletteKey = builtin.tintPalette.rawValue
                badge.usesPrimaryTint = builtin.usesPrimaryTint
            } else {
                badge.tintPaletteKey = badge.usesPrimaryTint
                    ? BadgeTintPalette.primary.rawValue
                    : BadgeTintPalette.secondary.rawValue
            }
        }
    }

    @discardableResult
    static func createCustom(
        title: String,
        systemImage: String = "tag.fill",
        tintPalette: BadgeTintPalette = .primary,
        in context: ModelContext
    ) throws -> BadgeDefinition {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw BadgeCatalogError.emptyTitle
        }

        let count = try context.fetchCount(FetchDescriptor<BadgeDefinition>())
        let badge = BadgeDefinition(
            identifier: UUID().uuidString,
            title: trimmedTitle,
            systemImage: systemImage,
            usesPrimaryTint: tintPalette == .primary,
            tintPaletteKey: tintPalette.rawValue,
            isCustom: true,
            sortOrder: count
        )
        context.insert(badge)
        return badge
    }

    static func delete(_ badge: BadgeDefinition, in context: ModelContext) throws {
        guard badge.isCustom else { return }

        let contacts = try context.fetch(FetchDescriptor<ContactSnapshot>())
        for contact in contacts {
            contact.badgeIDs = contact.badgeIDs.filter { $0 != badge.identifier }
        }

        context.delete(badge)
    }
}

enum BadgeCatalogError: LocalizedError {
    case emptyTitle

    var errorDescription: String? {
        switch self {
        case .emptyTitle: "Enter a badge name."
        }
    }
}

import Foundation
import SwiftData
import SwiftUI

@Model
final class BadgeDefinition {
    @Attribute(.unique) var identifier: String
    var title: String
    var systemImage: String
    var usesPrimaryTint: Bool
    var isCustom: Bool
    var createdAt: Date
    var sortOrder: Int

    init(
        identifier: String,
        title: String,
        systemImage: String,
        usesPrimaryTint: Bool = true,
        isCustom: Bool = false,
        createdAt: Date = .now,
        sortOrder: Int = 0
    ) {
        self.identifier = identifier
        self.title = title
        self.systemImage = systemImage
        self.usesPrimaryTint = usesPrimaryTint
        self.isCustom = isCustom
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }

    var tint: Color {
        usesPrimaryTint ? K.Color.primary : K.Color.secondary
    }
}

enum BadgeCatalogService {
    static func ensureDefaults(in context: ModelContext) throws {
        var descriptor = FetchDescriptor<BadgeDefinition>()
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return }

        for (index, builtin) in ContactBadge.allCases.enumerated() {
            context.insert(
                BadgeDefinition(
                    identifier: builtin.rawValue,
                    title: builtin.title,
                    systemImage: builtin.systemImage,
                    usesPrimaryTint: builtin.usesPrimaryTint,
                    isCustom: false,
                    sortOrder: index
                )
            )
        }
    }

    @discardableResult
    static func createCustom(
        title: String,
        systemImage: String = "tag.fill",
        usesPrimaryTint: Bool = true,
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
            usesPrimaryTint: usesPrimaryTint,
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

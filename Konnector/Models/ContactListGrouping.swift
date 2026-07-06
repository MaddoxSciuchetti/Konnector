import SwiftUI

enum ContactGroupMode: String, CaseIterable, Identifiable {
    case list
    case badge
    case score

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list: "List"
        case .badge: "Badge"
        case .score: "Score"
        }
    }

    var systemImage: String {
        switch self {
        case .list: "list.bullet"
        case .badge: "person.crop.circle.badge.checkmark"
        case .score: "circle.lefthalf.filled"
        }
    }
}

enum ScoreTier: Int, CaseIterable, Identifiable {
    case excellent
    case good
    case moderate
    case developing

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .excellent: "Excellent"
        case .good: "Good"
        case .moderate: "Moderate"
        case .developing: "Developing"
        }
    }

    var scoreRangeLabel: String {
        switch self {
        case .excellent: "8.0 – 10"
        case .good: "6.0 – 7.9"
        case .moderate: "4.0 – 5.9"
        case .developing: "0.0 – 3.9"
        }
    }

    var tint: Color {
        switch self {
        case .excellent: TraitScore.color(for: 9)
        case .good: TraitScore.color(for: 7)
        case .moderate: TraitScore.color(for: 5)
        case .developing: TraitScore.color(for: 2)
        }
    }

    static func tier(for score: Double) -> ScoreTier {
        switch score {
        case 8...: .excellent
        case 6..<8: .good
        case 4..<6: .moderate
        default: .developing
        }
    }
}

struct ContactListSection: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let tint: Color
    let systemImage: String
    let contacts: [ContactSnapshot]
}

enum ContactListGrouping {
    static func sections(
        for contacts: [ContactSnapshot],
        mode: ContactGroupMode,
        badgeCatalog: [BadgeDefinition]
    ) -> [ContactListSection] {
        switch mode {
        case .list:
            return []
        case .badge:
            return badgeSections(from: contacts, catalog: badgeCatalog)
        case .score:
            return scoreSections(from: contacts)
        }
    }

    private static func badgeSections(
        from contacts: [ContactSnapshot],
        catalog: [BadgeDefinition]
    ) -> [ContactListSection] {
        var sections = catalog.compactMap { badge -> ContactListSection? in
            let members = contacts
                .filter { $0.hasBadge(badge.identifier) }
                .sorted { $0.sortName.localizedCaseInsensitiveCompare($1.sortName) == .orderedAscending }

            guard !members.isEmpty else { return nil }

            return ContactListSection(
                id: "badge-\(badge.identifier)",
                title: badge.title,
                subtitle: nil,
                tint: badge.tint,
                systemImage: badge.systemImage,
                contacts: members
            )
        }

        let unbadged = contacts
            .filter { $0.badges.isEmpty }
            .sorted { $0.sortName.localizedCaseInsensitiveCompare($1.sortName) == .orderedAscending }

        if !unbadged.isEmpty {
            sections.append(
                ContactListSection(
                    id: "badge-none",
                    title: "No Badge",
                    subtitle: "Contacts without a badge",
                    tint: K.Color.secondary,
                    systemImage: "person.crop.circle",
                    contacts: unbadged
                )
            )
        }

        return sections
    }

    private static func scoreSections(from contacts: [ContactSnapshot]) -> [ContactListSection] {
        ScoreTier.allCases.compactMap { tier in
            let members = contacts
                .filter { ScoreTier.tier(for: $0.overallScore) == tier }
                .sorted { lhs, rhs in
                    if lhs.overallScore != rhs.overallScore {
                        return lhs.overallScore > rhs.overallScore
                    }
                    return lhs.sortName.localizedCaseInsensitiveCompare(rhs.sortName) == .orderedAscending
                }

            guard !members.isEmpty else { return nil }

            return ContactListSection(
                id: "score-\(tier.rawValue)",
                title: tier.title,
                subtitle: tier.scoreRangeLabel,
                tint: tier.tint,
                systemImage: "circle.lefthalf.filled",
                contacts: members
            )
        }
    }
}

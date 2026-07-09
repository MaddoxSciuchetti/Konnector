import SwiftUI

enum ContactBadge: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case friend
    case colleague
    case client
    case mentor
    case family

    var id: String { rawValue }

    var title: String {
        switch self {
        case .friend: "Friend"
        case .colleague: "Colleague"
        case .client: "Client"
        case .mentor: "Mentor"
        case .family: "Family"
        }
    }

    var systemImage: String {
        switch self {
        case .friend: "person.fill"
        case .colleague: "person.2.fill"
        case .client: "briefcase.fill"
        case .mentor: "lightbulb.fill"
        case .family: "house.fill"
        }
    }

    var tintPalette: BadgeTintPalette {
        switch self {
        case .friend: .primary
        case .colleague: .secondary
        case .client: .slate
        case .mentor: .sky
        case .family: .mist
        }
    }

    var tint: Color {
        tintPalette.color
    }

    var usesPrimaryTint: Bool {
        tintPalette == .primary
    }
}

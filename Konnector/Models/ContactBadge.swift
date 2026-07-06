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

    var tint: Color {
        switch self {
        case .friend, .mentor, .family: K.Color.primary
        case .colleague, .client: K.Color.secondary
        }
    }

    var usesPrimaryTint: Bool {
        switch self {
        case .friend, .mentor, .family: true
        case .colleague, .client: false
        }
    }
}

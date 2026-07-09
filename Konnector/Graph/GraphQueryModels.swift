import Foundation

struct GraphLabeledValue: Codable, Sendable {
    let label: String
    let value: String
}

struct GraphRelationshipValue: Codable, Sendable {
    let label: String
    let name: String
}

struct GraphContactPayload: Codable, Sendable {
    let sourceIdentifier: String
    let displayName: String
    let givenName: String
    let familyName: String
    let organizationName: String
    let departmentName: String
    let jobTitle: String
    let relationships: [GraphRelationshipValue]
    let emails: [GraphLabeledValue]
    let phones: [GraphLabeledValue]
    let badges: [String]
    let linkedInProfileURL: String
    let intelligenceRating: Int
    let integrityRating: Int
    let driveRating: Int
    let note: String
    let synchronizedAt: String
}

struct GraphSyncBatch: Codable, Sendable {
    let contacts: [GraphContactPayload]
    let deletedSourceIdentifiers: [String]
}

struct GraphNetworkNode: Codable, Sendable, Identifiable {
    let sourceIdentifier: String?
    let displayName: String?
    let givenName: String?
    let familyName: String?
    let jobTitle: String?
    let organizationName: String?
    let name: String?
    let kind: String
    let isCenter: Bool?

    var id: String {
        if let sourceIdentifier, !sourceIdentifier.isEmpty {
            return "contact:\(sourceIdentifier)"
        }
        return "\(kind):\(name ?? displayName ?? UUID().uuidString)"
    }

    var title: String {
        displayName ?? name ?? "Unknown"
    }
}

struct GraphNetworkEdge: Codable, Sendable, Identifiable {
    let type: String
    let label: String?
    let from: String
    let to: String
    let toKind: String?

    var id: String { "\(from)-\(type)-\(to)" }
}

struct GraphNetworkResponse: Codable, Sendable {
    let center: GraphNetworkNode
    let nodes: [GraphNetworkNode]
    let edges: [GraphNetworkEdge]
}

struct GraphCommonalitiesResponse: Codable, Sendable {
    let sharedOrganizations: [String]
    let sharedBadges: [String]
    let mutualConnections: [GraphMutualConnection]
}

struct GraphMutualConnection: Codable, Sendable, Identifiable {
    let sourceIdentifier: String
    let displayName: String

    var id: String { sourceIdentifier }
}

struct GraphSearchResponse: Codable, Sendable {
    let coworkers: [GraphCoworkerMatch]
    let byBadge: [GraphBadgeMatch]
    let related: [GraphRelatedMatch]
}

struct GraphCoworkerMatch: Codable, Sendable, Identifiable {
    let anchorName: String
    let sourceIdentifier: String
    let displayName: String
    let organizationName: String

    var id: String { sourceIdentifier }
}

struct GraphBadgeMatch: Codable, Sendable, Identifiable {
    let sourceIdentifier: String
    let displayName: String
    let badgeTitle: String

    var id: String { sourceIdentifier }
}

struct GraphRelatedMatch: Codable, Sendable, Identifiable {
    let anchorName: String
    let relatedKind: String
    let displayName: String
    let sourceIdentifier: String?

    var id: String { "\(anchorName)-\(displayName)" }
}

extension ContactSnapshot {
    func graphPayload(synchronizedAt: Date = .now) -> GraphContactPayload {
        GraphContactPayload(
            sourceIdentifier: sourceIdentifier,
            displayName: displayName,
            givenName: givenName,
            familyName: familyName,
            organizationName: organizationName,
            departmentName: departmentName,
            jobTitle: jobTitle,
            relationships: relationships.map {
                GraphRelationshipValue(label: $0.label, name: $0.name)
            },
            emails: emailAddresses.map { GraphLabeledValue(label: $0.label, value: $0.value) },
            phones: phoneNumbers.map { GraphLabeledValue(label: $0.label, value: $0.value) },
            badges: badgeIDs,
            linkedInProfileURL: linkedInProfileURL,
            intelligenceRating: intelligenceRating,
            integrityRating: integrityRating,
            driveRating: driveRating,
            note: note,
            synchronizedAt: ISO8601DateFormatter().string(from: synchronizedAt)
        )
    }
}

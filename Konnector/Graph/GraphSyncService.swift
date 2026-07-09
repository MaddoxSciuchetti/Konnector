import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class GraphSyncService {
    enum GraphSyncState: Equatable {
        case idle
        case syncing
        case failed(String)
    }

    private let modelContext: ModelContext
    private let client: GraphAPIClient
    private let demoMode: Bool
    private var syncTask: Task<Void, Never>?

    private(set) var graphSyncState: GraphSyncState = .idle
    private(set) var lastGraphSyncDate: Date?

    init(modelContext: ModelContext, demoMode: Bool) {
        self.modelContext = modelContext
        self.demoMode = demoMode
        self.client = GraphAPIClient(baseURL: GraphAPIConfiguration.baseURL)
    }

    func scheduleSync(deletedSourceIdentifiers: [String] = []) {
        guard GraphAPIConfiguration.isEnabled else { return }
        if syncTask != nil { return }

        syncTask = Task { [weak self] in
            await self?.syncNow(deletedSourceIdentifiers: deletedSourceIdentifiers)
            self?.syncTask = nil
        }
    }

    func syncNow(deletedSourceIdentifiers: [String] = []) async {
        guard GraphAPIConfiguration.isEnabled else { return }

        graphSyncState = .syncing
        do {
            let token = try await GraphAuthService.ensureAuthenticated(
                baseURL: GraphAPIConfiguration.baseURL,
                demoMode: demoMode
            )
            let contacts = try modelContext.fetch(FetchDescriptor<ContactSnapshot>())
            let batch = GraphSyncBatch(
                contacts: contacts.map { $0.graphPayload() },
                deletedSourceIdentifiers: deletedSourceIdentifiers
            )
            try await client.syncContacts(token: token, batch: batch)
            lastGraphSyncDate = .now
            graphSyncState = .idle
        } catch {
            graphSyncState = .failed(error.localizedDescription)
        }
    }

    func fetchNetwork(for contact: ContactSnapshot) async throws -> GraphNetworkResponse {
        let token = try await GraphAuthService.ensureAuthenticated(
            baseURL: GraphAPIConfiguration.baseURL,
            demoMode: demoMode
        )
        return try await client.fetchNetwork(
            token: token,
            sourceIdentifier: contact.sourceIdentifier
        )
    }

    func fetchCommonalities(
        between contactA: ContactSnapshot,
        and contactB: ContactSnapshot
    ) async throws -> GraphCommonalitiesResponse {
        let token = try await GraphAuthService.ensureAuthenticated(
            baseURL: GraphAPIConfiguration.baseURL,
            demoMode: demoMode
        )
        return try await client.fetchCommonalities(
            token: token,
            sourceIdentifierA: contactA.sourceIdentifier,
            sourceIdentifierB: contactB.sourceIdentifier
        )
    }

    func searchGraph(query: String) async throws -> GraphSearchResponse {
        let token = try await GraphAuthService.ensureAuthenticated(
            baseURL: GraphAPIConfiguration.baseURL,
            demoMode: demoMode
        )
        return try await client.search(token: token, query: query)
    }
}

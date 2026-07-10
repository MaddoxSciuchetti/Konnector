import Contacts
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ContactSyncService {
    enum SyncState: Equatable {
        case idle
        case syncing
        case failed(String)
    }

    private let modelContext: ModelContext
    private let contactsClient: any ContactsClientProtocol
    private let graphSyncService: GraphSyncService?
    private var syncTask: Task<Void, Never>?
    private var shouldSyncAgain = false
    private var storeChangeObserver: NSObjectProtocol?

    private(set) var authorization: ContactAuthorization = .notDetermined
    private(set) var syncState: SyncState = .idle
    private(set) var lastSyncDate: Date?

    init(
        modelContext: ModelContext,
        contactsClient: any ContactsClientProtocol = ContactsClient(),
        graphSyncService: GraphSyncService? = nil
    ) {
        self.modelContext = modelContext
        self.contactsClient = contactsClient
        self.graphSyncService = graphSyncService
        storeChangeObserver = NotificationCenter.default.addObserver(
            forName: .CNContactStoreDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleSync()
            }
        }
    }

    func refreshAuthorization() async {
        authorization = await contactsClient.authorizationStatus()
        if authorization.canReadContacts {
            scheduleSync()
        } else if authorization == .denied || authorization == .restricted {
            purgeSnapshots()
        }
    }

    func requestAccessAndSync() async {
        syncState = .syncing
        do {
            authorization = try await contactsClient.requestAccess()
            guard authorization.canReadContacts else {
                purgeSnapshots()
                syncState = .idle
                return
            }
            scheduleSync()
        } catch {
            authorization = await contactsClient.authorizationStatus()
            syncState = .failed(error.localizedDescription)
        }
    }

    func scheduleSync() {
        guard authorization.canReadContacts else { return }
        if syncTask != nil {
            shouldSyncAgain = true
            return
        }

        syncTask = Task { [weak self] in
            await self?.runSyncLoop()
        }
    }

    func syncNow() async {
        authorization = await contactsClient.authorizationStatus()
        guard authorization.canReadContacts else {
            purgeSnapshots()
            return
        }
        scheduleSync()
        let currentTask = syncTask
        await currentTask?.value
    }

    func retry() {
        syncState = .idle
        scheduleSync()
    }

    func dismissError() {
        if case .failed = syncState {
            syncState = .idle
        }
    }

    func contact(identifier: String) async throws -> SystemContact? {
        try await contactsClient.fetchContact(identifier: identifier)
    }

    func updateContactPhoto(identifier: String, imageData: Data?) async throws {
        try await contactsClient.updateContactImage(identifier: identifier, imageData: imageData)
    }

    private func runSyncLoop() async {
        repeat {
            shouldSyncAgain = false
            await synchronizeOnce()
        } while shouldSyncAgain
        syncTask = nil
    }

    private func synchronizeOnce() async {
        syncState = .syncing
        do {
            let imported = try await contactsClient.fetchContacts()
            let synchronizedAt = Date()
            let deletedSourceIdentifiers = try replaceSnapshots(with: imported, synchronizedAt: synchronizedAt)
            lastSyncDate = synchronizedAt
            syncState = .idle
            graphSyncService?.scheduleSync(deletedSourceIdentifiers: deletedSourceIdentifiers)
        } catch {
            syncState = .failed(error.localizedDescription)
        }
    }

    @discardableResult
    private func replaceSnapshots(with imported: [ContactImportDTO], synchronizedAt: Date) throws -> [String] {
        var deletedSourceIdentifiers: [String] = []
        try modelContext.transaction {
            let existing = try modelContext.fetch(FetchDescriptor<ContactSnapshot>())
            var existingByIdentifier = Dictionary(uniqueKeysWithValues: existing.map { ($0.sourceIdentifier, $0) })

            for dto in imported {
                if let snapshot = existingByIdentifier.removeValue(forKey: dto.sourceIdentifier) {
                    snapshot.update(from: dto, synchronizedAt: synchronizedAt)
                    snapshot.ensureSyncedBirthdayCareItem(in: modelContext)
                } else {
                    let snapshot = ContactSnapshot(dto: dto, synchronizedAt: synchronizedAt)
                    snapshot.isNewlyAdded = true
                    modelContext.insert(snapshot)
                    snapshot.ensureSyncedBirthdayCareItem(in: modelContext)
                }
            }

            for staleSnapshot in existingByIdentifier.values {
                deletedSourceIdentifiers.append(staleSnapshot.sourceIdentifier)
                VoiceNoteFiles.deleteFiles(for: staleSnapshot.voiceNotes)
                modelContext.delete(staleSnapshot)
            }
        }
        return deletedSourceIdentifiers
    }

    private func purgeSnapshots() {
        do {
            var deletedSourceIdentifiers: [String] = []
            try modelContext.transaction {
                let snapshots = try modelContext.fetch(FetchDescriptor<ContactSnapshot>())
                deletedSourceIdentifiers = snapshots.map(\.sourceIdentifier)
                let voiceNotes = try modelContext.fetch(FetchDescriptor<ContactVoiceNote>())
                VoiceNoteFiles.deleteFiles(for: voiceNotes)
                try modelContext.delete(model: ContactVoiceNote.self)
                try modelContext.delete(model: ContactSnapshot.self)
            }
            lastSyncDate = nil
            graphSyncService?.scheduleSync(deletedSourceIdentifiers: deletedSourceIdentifiers)
        } catch {
            syncState = .failed(error.localizedDescription)
        }
    }
}

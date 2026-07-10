import SwiftData
import SwiftUI

@main
struct KonnectorApp: App {
    private let modelContainer: ModelContainer
    private let appMode: AppMode
    @State private var syncService: ContactSyncService
    @State private var graphSyncService: GraphSyncService
    @State private var voiceNoteRecorder = VoiceNoteRecorder()

    init() {
        let mode: AppMode = ProcessInfo.processInfo.arguments.contains("--demo-data") ? .demo : .live
        let schema = Schema([ContactSnapshot.self, ContactVoiceNote.self, ContactCareItem.self, BadgeDefinition.self])

        do {
            let bootstrap = try Self.bootstrap(mode: mode, schema: schema)
            modelContainer = bootstrap.container
            appMode = mode

            let graphSync = GraphSyncService(
                modelContext: bootstrap.container.mainContext,
                demoMode: mode == .demo
            )
            _graphSyncService = State(initialValue: graphSync)
            _syncService = State(
                initialValue: ContactSyncService(
                    modelContext: bootstrap.container.mainContext,
                    contactsClient: bootstrap.contactsClient,
                    graphSyncService: graphSync
                )
            )
        } catch let error as AppBootstrapError {
            fatalError(error.debugDescription)
        } catch {
            fatalError("Unable to create the contact store (\(mode) mode): \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(appMode: appMode)
                .environment(syncService)
                .environment(graphSyncService)
                .environment(voiceNoteRecorder)
                .tint(K.Color.blue)
        }
        .modelContainer(modelContainer)
    }
}

private struct AppBootstrapResult {
    let container: ModelContainer
    let contactsClient: any ContactsClientProtocol
}

private enum AppBootstrapError: LocalizedError {
    case stepFailed(String, Error)
    case storeRecoveryFailed(Error)

    var debugDescription: String {
        switch self {
        case .stepFailed(let step, let error):
            let nsError = error as NSError
            return """
            Unable to create the contact store at step: \(step)
            Domain: \(nsError.domain) Code: \(nsError.code)
            Description: \(nsError.localizedDescription)
            Underlying: \(String(describing: nsError.userInfo[NSUnderlyingErrorKey] ?? "none"))
            """
        case .storeRecoveryFailed(let error):
            return "Unable to recreate the contact store after reset: \(error)"
        }
    }
}

private extension KonnectorApp {
    static func bootstrap(mode: AppMode, schema: Schema) throws -> AppBootstrapResult {
        let configuration: ModelConfiguration
        let contactsClient: any ContactsClientProtocol
        let storeDirectory: URL?

        switch mode {
        case .demo:
            configuration = ModelConfiguration(
                "DemoContacts",
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            contactsClient = DemoContactsClient()
            storeDirectory = nil
        case .live:
            let fileManager = FileManager.default
            var directory = fileManager
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appending(path: "KonnectorContacts", directoryHint: .isDirectory)

            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                try directory.setResourceValues(resourceValues)
            } catch {
                throw AppBootstrapError.stepFailed("prepare store directory", error)
            }

            configuration = ModelConfiguration(
                "Contacts",
                schema: schema,
                url: directory.appending(path: "Contacts.store"),
                cloudKitDatabase: .none
            )
            contactsClient = ContactsClient()
            storeDirectory = directory

            do {
                try VoiceNoteFiles.ensureDirectoryExists()
            } catch {
                throw AppBootstrapError.stepFailed("prepare voice note directory", error)
            }
        }

        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            guard let storeDirectory else {
                throw AppBootstrapError.stepFailed("create model container", error)
            }

            do {
                try resetPersistentStore(at: storeDirectory)
                try VoiceNoteFiles.ensureDirectoryExists()
                container = try ModelContainer(for: schema, configurations: [configuration])
            } catch let recoveryError {
                throw AppBootstrapError.storeRecoveryFailed(recoveryError)
            }
        }

        do {
            try BadgeCatalogService.ensureDefaults(in: container.mainContext)
            try container.mainContext.save()
        } catch {
            throw AppBootstrapError.stepFailed("seed default badges", error)
        }

        return AppBootstrapResult(container: container, contactsClient: contactsClient)
    }

    static func resetPersistentStore(at storeDirectory: URL) throws {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: storeDirectory.path()) {
            try fileManager.removeItem(at: storeDirectory)
        }

        try fileManager.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var directory = storeDirectory
        try directory.setResourceValues(resourceValues)
    }
}

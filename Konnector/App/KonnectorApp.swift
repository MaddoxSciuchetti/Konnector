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
        do {
            let mode: AppMode = ProcessInfo.processInfo.arguments.contains("--demo-data") ? .demo : .live
            let schema = Schema([ContactSnapshot.self, ContactVoiceNote.self, ContactCareItem.self, BadgeDefinition.self])
            let configuration: ModelConfiguration
            let contactsClient: any ContactsClientProtocol

            switch mode {
            case .demo:
                configuration = ModelConfiguration(
                    "DemoContacts",
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
                contactsClient = DemoContactsClient()
            case .live:
                let fileManager = FileManager.default
                var storeDirectory = fileManager
                    .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appending(path: "KonnectorContacts", directoryHint: .isDirectory)
                try fileManager.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                try storeDirectory.setResourceValues(resourceValues)
                configuration = ModelConfiguration(
                    "Contacts",
                    schema: schema,
                    url: storeDirectory.appending(path: "Contacts.store"),
                    cloudKitDatabase: .none
                )
                contactsClient = ContactsClient()
                try VoiceNoteFiles.ensureDirectoryExists()
            }

            let container = try ModelContainer(for: schema, configurations: [configuration])
            try BadgeCatalogService.ensureDefaults(in: container.mainContext)
            try container.mainContext.save()
            modelContainer = container
            appMode = mode
            let graphSync = GraphSyncService(modelContext: container.mainContext, demoMode: mode == .demo)
            _graphSyncService = State(initialValue: graphSync)
            _syncService = State(
                initialValue: ContactSyncService(
                    modelContext: container.mainContext,
                    contactsClient: contactsClient,
                    graphSyncService: graphSync
                )
            )
        } catch {
            fatalError("Unable to create the contact store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(appMode: appMode)
                .environment(syncService)
                .environment(graphSyncService)
                .environment(voiceNoteRecorder)
                .tint(K.Color.primary)
        }
        .modelContainer(modelContainer)
    }
}

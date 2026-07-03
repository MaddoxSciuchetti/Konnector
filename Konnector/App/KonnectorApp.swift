import SwiftData
import SwiftUI

@main
struct KonnectorApp: App {
    private let modelContainer: ModelContainer
    @State private var syncService: ContactSyncService

    init() {
        do {
            let fileManager = FileManager.default
            var storeDirectory = fileManager
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appending(path: "KonnectorContacts", directoryHint: .isDirectory)
            try fileManager.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try storeDirectory.setResourceValues(resourceValues)

            let schema = Schema([ContactSnapshot.self])
            let configuration = ModelConfiguration(
                "Contacts",
                schema: schema,
                url: storeDirectory.appending(path: "Contacts.store"),
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])
            modelContainer = container
            _syncService = State(
                initialValue: ContactSyncService(modelContext: container.mainContext)
            )
        } catch {
            fatalError("Unable to create the contact store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(syncService)
        }
        .modelContainer(modelContainer)
    }
}

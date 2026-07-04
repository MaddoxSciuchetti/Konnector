import SwiftData
import XCTest
@testable import Konnector

@MainActor
final class DemoContactsClientTests: XCTestCase {
    func testDemoContactsImportIntoMemoryAndAreSearchable() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ContactSnapshot.self,
            configurations: configuration
        )
        let client = DemoContactsClient()
        let service = ContactSyncService(
            modelContext: container.mainContext,
            contactsClient: client
        )

        await service.syncNow()
        let snapshots = try container.mainContext.fetch(FetchDescriptor<ContactSnapshot>())

        XCTAssertEqual(snapshots.count, 8)
        XCTAssertTrue(snapshots.contains { $0.matches(search: "Analytical Engine") })
        XCTAssertTrue(snapshots.contains { $0.matches(search: "+44 20 7946 0101") })
        XCTAssertTrue(snapshots.contains { $0.matches(search: "marie@example.com") })
    }

    func testDemoContactUsesSafePreviewPresentation() async throws {
        let client = DemoContactsClient()
        let contact = try await client.fetchContact(identifier: "demo-ada")

        XCTAssertEqual(contact?.presentation, .preview)
        XCTAssertEqual(contact?.value.givenName, "Ada")
    }

    func testMissingDemoContactReturnsNil() async throws {
        let client = DemoContactsClient()
        let contact = try await client.fetchContact(identifier: "missing")

        XCTAssertNil(contact)
    }
}

import SwiftData
import XCTest
@testable import Konnector

@MainActor
final class ContactSyncServiceTests: XCTestCase {
    func testSyncInsertsUpdatesAndDeletesSnapshots() async throws {
        let container = try inMemoryContainer()
        let client = MockContactsClient(contacts: [makeDTO(id: "1", name: "Ada"), makeDTO(id: "2", name: "Grace")])
        let service = ContactSyncService(modelContext: container.mainContext, contactsClient: client)

        await service.syncNow()
        var snapshots = try container.mainContext.fetch(FetchDescriptor<ContactSnapshot>())
        XCTAssertEqual(snapshots.count, 2)

        await client.setContacts([makeDTO(id: "1", name: "Augusta")])
        await service.syncNow()
        snapshots = try container.mainContext.fetch(FetchDescriptor<ContactSnapshot>())

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.sourceIdentifier, "1")
        XCTAssertEqual(snapshots.first?.givenName, "Augusta")
    }

    func testRevokedAuthorizationPurgesSnapshots() async throws {
        let container = try inMemoryContainer()
        let client = MockContactsClient(contacts: [makeDTO(id: "1", name: "Ada")])
        let service = ContactSyncService(modelContext: container.mainContext, contactsClient: client)

        await service.syncNow()
        await client.setAuthorization(.denied)
        await service.refreshAuthorization()

        let snapshots = try container.mainContext.fetch(FetchDescriptor<ContactSnapshot>())
        XCTAssertTrue(snapshots.isEmpty)
    }

    func testOverlappingRequestsAreSerialized() async {
        let container = try! inMemoryContainer()
        let client = MockContactsClient(contacts: [makeDTO(id: "1", name: "Ada")], delay: .milliseconds(30))
        let service = ContactSyncService(modelContext: container.mainContext, contactsClient: client)

        await service.refreshAuthorization()
        service.scheduleSync()
        service.scheduleSync()
        await service.syncNow()

        let maximumConcurrentFetches = await client.maximumConcurrentFetches
        XCTAssertEqual(maximumConcurrentFetches, 1)
    }

    private func inMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: ContactSnapshot.self, configurations: configuration)
    }
}

private actor MockContactsClient: ContactsClientProtocol {
    private var contacts: [ContactImportDTO]
    private var authorization: ContactAuthorization
    private let delay: Duration
    private var activeFetches = 0
    private(set) var maximumConcurrentFetches = 0

    init(
        contacts: [ContactImportDTO],
        authorization: ContactAuthorization = .authorized,
        delay: Duration = .zero
    ) {
        self.contacts = contacts
        self.authorization = authorization
        self.delay = delay
    }

    func authorizationStatus() async -> ContactAuthorization { authorization }

    func requestAccess() async throws -> ContactAuthorization { authorization }

    func fetchContacts() async throws -> [ContactImportDTO] {
        activeFetches += 1
        maximumConcurrentFetches = max(maximumConcurrentFetches, activeFetches)
        if delay != .zero {
            try await Task.sleep(for: delay)
        }
        activeFetches -= 1
        return contacts
    }

    func fetchContact(identifier: String) async throws -> SystemContact? { nil }

    func setContacts(_ contacts: [ContactImportDTO]) {
        self.contacts = contacts
    }

    func setAuthorization(_ authorization: ContactAuthorization) {
        self.authorization = authorization
    }
}

func makeDTO(id: String, name: String) -> ContactImportDTO {
    ContactImportDTO(
        sourceIdentifier: id,
        givenName: name,
        middleName: "",
        familyName: "",
        namePrefix: "",
        nameSuffix: "",
        nickname: "",
        organizationName: "",
        departmentName: "",
        jobTitle: "",
        displayName: name,
        sortName: name,
        phoneNumbers: [LabeledStringValue(label: "mobile", value: "555")],
        emailAddresses: [LabeledStringValue(label: "work", value: "\(name.lowercased())@example.com")],
        postalAddresses: [],
        birthday: nil,
        nonGregorianBirthday: nil,
        urlAddresses: [],
        relationships: [],
        socialProfiles: [],
        thumbnailData: nil
    )
}

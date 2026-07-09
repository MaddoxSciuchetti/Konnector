import XCTest
@testable import Konnector

@MainActor
final class AppStateTests: XCTestCase {
    func testRoutingForEveryAuthorizationState() {
        XCTAssertEqual(route(false, .notDetermined), .onboarding)
        XCTAssertEqual(route(true, .notDetermined), .onboarding)
        XCTAssertEqual(route(true, .denied), .onboarding)
        XCTAssertEqual(route(true, .restricted), .onboarding)
        XCTAssertEqual(route(true, .limited), .contacts)
        XCTAssertEqual(route(true, .authorized), .contacts)
    }

    func testDemoModeAlwaysBypassesOnboarding() {
        XCTAssertEqual(
            AppRoute.resolve(
                hasCompletedOnboarding: false,
                authorization: .notDetermined,
                appMode: .demo
            ),
            .contacts
        )
    }

    func testSnapshotSearchesNameOrganizationPhoneAndEmail() {
        var dto = makeDTO(id: "1", name: "José")
        dto.organizationName = "Analytical Engine"
        let snapshot = ContactSnapshot(dto: dto, synchronizedAt: .now)

        XCTAssertTrue(snapshot.matches(search: "jose"))
        XCTAssertTrue(snapshot.matches(search: "analytical"))
        XCTAssertTrue(snapshot.matches(search: "555"))
        XCTAssertTrue(snapshot.matches(search: "josé@example.com"))
        XCTAssertFalse(snapshot.matches(search: "missing"))
    }

    func testPrimaryLabelShowsOnlyPersonalNameWhenAvailable() {
        var dto = makeDTO(id: "1", name: "Ada Lovelace")
        dto.familyName = "Lovelace"
        dto.givenName = "Ada"
        dto.displayName = "Ada Lovelace"
        dto.phoneNumbers = [LabeledStringValue(label: "mobile", value: "+1 555 0100")]

        let snapshot = ContactSnapshot(dto: dto, synchronizedAt: .now)

        XCTAssertEqual(snapshot.primaryLabel, "Ada Lovelace")
        XCTAssertNil(snapshot.subtitle)
    }

    func testPrimaryLabelUsesOrganizationWhenPersonalNameMissing() {
        var dto = makeDTO(id: "1", name: "")
        dto.givenName = ""
        dto.displayName = "Acme"
        dto.organizationName = "Acme"
        dto.phoneNumbers = [LabeledStringValue(label: "mobile", value: "+1 555 0100")]

        let snapshot = ContactSnapshot(dto: dto, synchronizedAt: .now)

        XCTAssertEqual(snapshot.primaryLabel, "Acme")
        XCTAssertNil(snapshot.subtitle)
    }

    func testPrimaryLabelUsesEmailBeforePhoneWhenPersonalNameMissing() {
        var dto = makeDTO(id: "1", name: "")
        dto.givenName = ""
        dto.displayName = "Unnamed Contact"
        dto.organizationName = ""
        dto.phoneNumbers = [LabeledStringValue(label: "mobile", value: "+1 555 0100")]
        dto.emailAddresses = [LabeledStringValue(label: "work", value: "team@example.com")]

        let snapshot = ContactSnapshot(dto: dto, synchronizedAt: .now)

        XCTAssertEqual(snapshot.primaryLabel, "team@example.com")
    }

    func testMarkDetailOpenedClearsNewlyAddedFlag() {
        let snapshot = ContactSnapshot(dto: makeDTO(id: "1", name: "Ada"), synchronizedAt: .now)
        snapshot.isNewlyAdded = true

        snapshot.markDetailOpened()

        XCTAssertTrue(snapshot.hasOpenedDetail)
        XCTAssertFalse(snapshot.isNewlyAdded)
    }

    private func route(_ completed: Bool, _ authorization: ContactAuthorization) -> AppRoute {
        AppRoute.resolve(
            hasCompletedOnboarding: completed,
            authorization: authorization,
            appMode: .live
        )
    }
}

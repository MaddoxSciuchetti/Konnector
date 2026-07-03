import XCTest
@testable import Konnector

@MainActor
final class AppStateTests: XCTestCase {
    func testRoutingForEveryAuthorizationState() {
        XCTAssertEqual(AppRoute.resolve(hasCompletedOnboarding: false, authorization: .notDetermined), .onboarding)
        XCTAssertEqual(AppRoute.resolve(hasCompletedOnboarding: true, authorization: .notDetermined), .onboarding)
        XCTAssertEqual(AppRoute.resolve(hasCompletedOnboarding: true, authorization: .denied), .onboarding)
        XCTAssertEqual(AppRoute.resolve(hasCompletedOnboarding: true, authorization: .restricted), .onboarding)
        XCTAssertEqual(AppRoute.resolve(hasCompletedOnboarding: true, authorization: .limited), .contacts)
        XCTAssertEqual(AppRoute.resolve(hasCompletedOnboarding: true, authorization: .authorized), .contacts)
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
}

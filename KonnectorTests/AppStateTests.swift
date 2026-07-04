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

    private func route(_ completed: Bool, _ authorization: ContactAuthorization) -> AppRoute {
        AppRoute.resolve(
            hasCompletedOnboarding: completed,
            authorization: authorization,
            appMode: .live
        )
    }
}

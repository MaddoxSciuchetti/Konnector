import XCTest
@testable import Konnector

final class LinkedInConnectionServiceTests: XCTestCase {
    func testNormalizedProfileURLAcceptsFullHTTPSURL() {
        let normalized = LinkedInConnectionService.normalizedProfileURL(
            from: "https://www.linkedin.com/in/ada-lovelace/"
        )

        XCTAssertEqual(normalized, "https://www.linkedin.com/in/ada-lovelace")
    }

    func testNormalizedProfileURLBuildsFromUsername() {
        let normalized = LinkedInConnectionService.normalizedProfileURL(from: "ada-lovelace")

        XCTAssertEqual(normalized, "https://www.linkedin.com/in/ada-lovelace")
    }

    func testNormalizedProfileURLRejectsNonLinkedInHost() {
        XCTAssertNil(LinkedInConnectionService.normalizedProfileURL(from: "https://example.com/in/ada"))
    }

    func testProfileSlugExtractsVanityName() {
        let slug = LinkedInConnectionService.profileSlug(
            from: "https://www.linkedin.com/in/ada-lovelace"
        )

        XCTAssertEqual(slug, "ada-lovelace")
    }

    func testContactSnapshotDetectsLinkedInProfileFromSocialProfiles() {
        var dto = makeLinkedInTestDTO(id: "1", name: "Ada Lovelace")
        dto.socialProfiles = [
            SocialProfileValue(
                label: "Professional",
                service: "LinkedIn",
                username: "ada-lovelace",
                urlString: "https://www.linkedin.com/in/ada-lovelace"
            )
        ]

        let snapshot = ContactSnapshot(dto: dto, synchronizedAt: .now)

        XCTAssertEqual(
            snapshot.detectedLinkedInProfileURL,
            "https://www.linkedin.com/in/ada-lovelace"
        )
    }

    func testMarkLinkedInConnectedStoresDetectedProfileURL() {
        var dto = makeLinkedInTestDTO(id: "1", name: "Ada Lovelace")
        dto.socialProfiles = [
            SocialProfileValue(
                label: "Professional",
                service: "LinkedIn",
                username: "ada-lovelace",
                urlString: "https://www.linkedin.com/in/ada-lovelace"
            )
        ]

        let snapshot = ContactSnapshot(dto: dto, synchronizedAt: .now)
        snapshot.markLinkedInConnected()

        XCTAssertTrue(snapshot.isLinkedInConnected)
        XCTAssertEqual(snapshot.linkedInProfileURL, "https://www.linkedin.com/in/ada-lovelace")
        XCTAssertNotNil(snapshot.linkedInConnectedAt)
    }
}

private func makeLinkedInTestDTO(id: String, name: String) -> ContactImportDTO {
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
        phoneNumbers: [],
        emailAddresses: [],
        postalAddresses: [],
        birthday: nil,
        nonGregorianBirthday: nil,
        urlAddresses: [],
        relationships: [],
        socialProfiles: [],
        thumbnailData: nil
    )
}

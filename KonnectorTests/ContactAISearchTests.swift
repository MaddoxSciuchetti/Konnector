import XCTest
@testable import Konnector

@MainActor
final class ContactAISearchTests: XCTestCase {
    func testRanksContactsByNaturalLanguageDescription() {
        let contacts = DemoContactFixtures.contacts.map {
            ContactSnapshot(dto: $0, synchronizedAt: .now)
        }

        let cryptographyMatches = ContactAISearchService.search(
            contacts: contacts,
            badgeCatalog: [],
            query: "someone who worked in cryptography in the UK"
        )
        XCTAssertEqual(cryptographyMatches.first?.contact.givenName, "Alan")

        let physicistMatches = ContactAISearchService.search(
            contacts: contacts,
            badgeCatalog: [],
            query: "physicist in France"
        )
        XCTAssertEqual(physicistMatches.first?.contact.givenName, "Marie")

        let executiveMatches = ContactAISearchService.search(
            contacts: contacts,
            badgeCatalog: [],
            query: "CEO at a cloud company"
        )
        XCTAssertEqual(executiveMatches.first?.contact.givenName, "Satya")
    }

    func testIncludesUserNotesInSearchCorpus() {
        var dto = makeDTO(id: "note-test", name: "Taylor")
        dto.jobTitle = "Designer"
        let contact = ContactSnapshot(dto: dto, synchronizedAt: .now)
        contact.note = "Met at the design conference in Austin"

        let matches = ContactAISearchService.search(
            contacts: [contact],
            badgeCatalog: [],
            query: "design conference Austin"
        )

        XCTAssertEqual(matches.count, 1)
        XCTAssertTrue(matches[0].matchedTerms.contains(where: { $0.localizedCaseInsensitiveContains("design") || $0.localizedCaseInsensitiveContains("austin") }))
    }

    func testReturnsEmptyResultsForBlankQuery() {
        let contact = ContactSnapshot(dto: makeDTO(id: "1", name: "Alex"), synchronizedAt: .now)
        XCTAssertTrue(ContactAISearchService.search(contacts: [contact], badgeCatalog: [], query: "").isEmpty)
        XCTAssertTrue(ContactAISearchService.search(contacts: [contact], badgeCatalog: [], query: "   ").isEmpty)
    }
}

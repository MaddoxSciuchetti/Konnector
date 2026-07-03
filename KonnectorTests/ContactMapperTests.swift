import Contacts
import XCTest
@testable import Konnector

final class ContactMapperTests: XCTestCase {
    func testMapsBroadContactProfile() {
        let contact = CNMutableContact()
        contact.givenName = "Ada"
        contact.middleName = "M"
        contact.familyName = "Lovelace"
        contact.namePrefix = "Countess"
        contact.nameSuffix = "I"
        contact.nickname = "Enchantress of Numbers"
        contact.organizationName = "Analytical Engine"
        contact.departmentName = "Research"
        contact.jobTitle = "Mathematician"
        contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "+1 555 0100"))]
        contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "ada@example.com")]

        let address = CNMutablePostalAddress()
        address.street = "1 Engine Way"
        address.city = "London"
        address.state = "London"
        address.postalCode = "N1"
        address.country = "United Kingdom"
        address.isoCountryCode = "GB"
        contact.postalAddresses = [CNLabeledValue(label: CNLabelHome, value: address.copy() as! CNPostalAddress)]
        contact.birthday = DateComponents(year: 1815, month: 12, day: 10)
        contact.urlAddresses = [CNLabeledValue(label: CNLabelURLAddressHomePage, value: "https://example.com" as NSString)]
        contact.contactRelations = [CNLabeledValue(label: CNLabelContactRelationFriend, value: CNContactRelation(name: "Charles"))]
        contact.socialProfiles = [
            CNLabeledValue(
                label: CNLabelWork,
                value: CNSocialProfile(
                    urlString: "https://social.example/ada",
                    username: "ada",
                    userIdentifier: "42",
                    service: "Example"
                )
            )
        ]

        let dto = ContactsClient.makeDTO(from: contact)

        XCTAssertEqual(dto.sourceIdentifier, contact.identifier)
        XCTAssertEqual(dto.givenName, "Ada")
        XCTAssertEqual(dto.middleName, "M")
        XCTAssertEqual(dto.familyName, "Lovelace")
        XCTAssertEqual(dto.namePrefix, "Countess")
        XCTAssertEqual(dto.nameSuffix, "I")
        XCTAssertEqual(dto.nickname, "Enchantress of Numbers")
        XCTAssertEqual(dto.organizationName, "Analytical Engine")
        XCTAssertEqual(dto.departmentName, "Research")
        XCTAssertEqual(dto.jobTitle, "Mathematician")
        XCTAssertEqual(dto.phoneNumbers.first?.value, "+1 555 0100")
        XCTAssertEqual(dto.emailAddresses.first?.value, "ada@example.com")
        XCTAssertEqual(dto.postalAddresses.first?.city, "London")
        XCTAssertEqual(dto.birthday?.year, 1815)
        XCTAssertEqual(dto.urlAddresses.first?.value, "https://example.com")
        XCTAssertEqual(dto.relationships.first?.name, "Charles")
        XCTAssertEqual(dto.socialProfiles.first?.username, "ada")
        XCTAssertNil(dto.thumbnailData)
        XCTAssertTrue(dto.searchText.contains("ada@example.com"))
    }

    func testUsesOrganizationWhenNameIsMissing() {
        let contact = CNMutableContact()
        contact.organizationName = "Acme"

        let dto = ContactsClient.makeDTO(from: contact)

        XCTAssertEqual(dto.displayName, "Acme")
        XCTAssertEqual(dto.sortName, "Acme")
    }
}

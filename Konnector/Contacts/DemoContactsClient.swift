import Contacts
import Foundation

enum DemoContactFixtures {
    static let contacts: [ContactImportDTO] = [
        contact(
            id: "demo-ada",
            givenName: "Ada",
            familyName: "Lovelace",
            organization: "Analytical Engine Society",
            jobTitle: "Mathematician",
            phone: "+44 20 7946 0101",
            email: "ada@example.com",
            city: "London",
            country: "United Kingdom",
            birthday: ContactDateValue(year: 1815, month: 12, day: 10, calendarIdentifier: "gregorian"),
            socialService: "Mastodon",
            username: "ada"
        ),
        contact(
            id: "demo-grace",
            givenName: "Grace",
            familyName: "Hopper",
            organization: "Computing Pioneers",
            jobTitle: "Rear Admiral",
            phone: "+1 202 555 0102",
            email: "grace@example.com",
            city: "Arlington",
            country: "United States"
        ),
        contact(
            id: "demo-alan",
            givenName: "Alan",
            familyName: "Turing",
            organization: "Bletchley Research",
            jobTitle: "Computer Scientist",
            phone: "+44 20 7946 0103",
            email: "alan@example.com",
            city: "Manchester",
            country: "United Kingdom"
        ),
        contact(
            id: "demo-katherine",
            givenName: "Katherine",
            familyName: "Johnson",
            organization: "Orbital Mechanics Lab",
            jobTitle: "Research Mathematician",
            phone: "+1 757 555 0104",
            email: "katherine@example.com",
            city: "Hampton",
            country: "United States"
        ),
        contact(
            id: "demo-linus",
            givenName: "Linus",
            familyName: "Torvalds",
            organization: "Open Source Foundation",
            jobTitle: "Software Engineer",
            phone: "+1 503 555 0105",
            email: "linus@example.com",
            city: "Portland",
            country: "United States"
        ),
        contact(
            id: "demo-maya",
            givenName: "Maya",
            familyName: "Angelou",
            organization: "Writers Collective",
            jobTitle: "Author",
            phone: "+1 336 555 0106",
            email: "maya@example.com",
            city: "Winston-Salem",
            country: "United States"
        ),
        contact(
            id: "demo-satya",
            givenName: "Satya",
            familyName: "Nadella",
            organization: "Cloud Systems",
            jobTitle: "Chief Executive Officer",
            phone: "+1 425 555 0107",
            email: "satya@example.com",
            city: "Redmond",
            country: "United States"
        ),
        contact(
            id: "demo-marie",
            givenName: "Marie",
            familyName: "Curie",
            organization: "Radium Institute",
            jobTitle: "Physicist",
            phone: "+33 1 55 55 0108",
            email: "marie@example.com",
            city: "Paris",
            country: "France",
            birthday: ContactDateValue(year: 1867, month: 11, day: 7, calendarIdentifier: "gregorian"),
            socialService: "ResearchNet",
            username: "marie.curie"
        )
    ]

    private static func contact(
        id: String,
        givenName: String,
        familyName: String,
        organization: String,
        jobTitle: String,
        phone: String,
        email: String,
        city: String,
        country: String,
        birthday: ContactDateValue? = nil,
        socialService: String? = nil,
        username: String? = nil
    ) -> ContactImportDTO {
        let socialProfiles: [SocialProfileValue]
        if let socialService, let username {
            socialProfiles = [
                SocialProfileValue(
                    label: "Profile",
                    service: socialService,
                    username: username,
                    urlString: "https://example.com/\(username)"
                )
            ]
        } else {
            socialProfiles = []
        }

        return ContactImportDTO(
            sourceIdentifier: id,
            givenName: givenName,
            middleName: "",
            familyName: familyName,
            namePrefix: "",
            nameSuffix: "",
            nickname: "",
            organizationName: organization,
            departmentName: "",
            jobTitle: jobTitle,
            displayName: "\(givenName) \(familyName)",
            sortName: "\(familyName) \(givenName)",
            phoneNumbers: [LabeledStringValue(label: "Mobile", value: phone)],
            emailAddresses: [LabeledStringValue(label: "Work", value: email)],
            postalAddresses: [
                PostalAddressValue(
                    label: "Work",
                    street: "1 Example Street",
                    city: city,
                    state: "",
                    postalCode: "",
                    country: country,
                    isoCountryCode: ""
                )
            ],
            birthday: birthday,
            nonGregorianBirthday: nil,
            urlAddresses: [LabeledStringValue(label: "Website", value: "https://example.com")],
            relationships: [],
            socialProfiles: socialProfiles,
            thumbnailData: nil
        )
    }
}

actor DemoContactsClient: ContactsClientProtocol {
    private let contacts = DemoContactFixtures.contacts

    func authorizationStatus() async -> ContactAuthorization { .authorized }

    func requestAccess() async throws -> ContactAuthorization { .authorized }

    func fetchContacts() async throws -> [ContactImportDTO] { contacts }

    func fetchContact(identifier: String) async throws -> SystemContact? {
        guard let dto = contacts.first(where: { $0.sourceIdentifier == identifier }) else {
            return nil
        }
        return SystemContact(value: Self.makeContact(from: dto), presentation: .preview)
    }

    func updateContactImage(identifier: String, imageData: Data?) async throws {
        // Demo contacts are in-memory only; photo updates stay on the local snapshot.
        _ = identifier
        _ = imageData
    }

    private static func makeContact(from dto: ContactImportDTO) -> CNContact {
        let contact = CNMutableContact()
        contact.givenName = dto.givenName
        contact.middleName = dto.middleName
        contact.familyName = dto.familyName
        contact.namePrefix = dto.namePrefix
        contact.nameSuffix = dto.nameSuffix
        contact.nickname = dto.nickname
        contact.organizationName = dto.organizationName
        contact.departmentName = dto.departmentName
        contact.jobTitle = dto.jobTitle
        contact.phoneNumbers = dto.phoneNumbers.map {
            CNLabeledValue(label: $0.label, value: CNPhoneNumber(stringValue: $0.value))
        }
        contact.emailAddresses = dto.emailAddresses.map {
            CNLabeledValue(label: $0.label, value: $0.value as NSString)
        }
        contact.postalAddresses = dto.postalAddresses.map { value in
            let address = CNMutablePostalAddress()
            address.street = value.street
            address.city = value.city
            address.state = value.state
            address.postalCode = value.postalCode
            address.country = value.country
            address.isoCountryCode = value.isoCountryCode
            return CNLabeledValue<CNPostalAddress>(label: value.label, value: address)
        }
        contact.birthday = dto.birthday.map {
            DateComponents(year: $0.year, month: $0.month, day: $0.day)
        }
        contact.urlAddresses = dto.urlAddresses.map {
            CNLabeledValue(label: $0.label, value: $0.value as NSString)
        }
        contact.contactRelations = dto.relationships.map {
            CNLabeledValue(label: $0.label, value: CNContactRelation(name: $0.name))
        }
        contact.socialProfiles = dto.socialProfiles.map {
            CNLabeledValue(
                label: $0.label,
                value: CNSocialProfile(
                    urlString: $0.urlString,
                    username: $0.username,
                    userIdentifier: $0.username,
                    service: $0.service
                )
            )
        }
        return contact
    }
}

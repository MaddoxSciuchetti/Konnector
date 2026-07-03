import Contacts
import Foundation

enum ContactAuthorization: Equatable, Sendable {
    case notDetermined
    case limited
    case authorized
    case denied
    case restricted

    var canReadContacts: Bool {
        self == .authorized || self == .limited
    }
}

struct SystemContact: @unchecked Sendable {
    let value: CNContact
}

protocol ContactsClientProtocol: Sendable {
    func authorizationStatus() async -> ContactAuthorization
    func requestAccess() async throws -> ContactAuthorization
    func fetchContacts() async throws -> [ContactImportDTO]
    func fetchContact(identifier: String) async throws -> SystemContact?
}

actor ContactsClient: ContactsClientProtocol {
    private let store = CNContactStore()

    func authorizationStatus() async -> ContactAuthorization {
        Self.map(CNContactStore.authorizationStatus(for: .contacts))
    }

    func requestAccess() async throws -> ContactAuthorization {
        _ = try await store.requestAccess(for: .contacts)
        return await authorizationStatus()
    }

    func fetchContacts() async throws -> [ContactImportDTO] {
        let request = CNContactFetchRequest(keysToFetch: Self.keysToFetch)
        request.sortOrder = .userDefault
        request.unifyResults = true

        var results: [ContactImportDTO] = []
        try store.enumerateContacts(with: request) { contact, _ in
            results.append(Self.makeDTO(from: contact))
        }
        return results
    }

    func fetchContact(identifier: String) async throws -> SystemContact? {
        do {
            let contact = try store.unifiedContact(
                withIdentifier: identifier,
                keysToFetch: Self.keysToFetch
            )
            return SystemContact(value: contact)
        } catch let error as CNError where error.code == .recordDoesNotExist {
            return nil
        }
    }

    private static var keysToFetch: [CNKeyDescriptor] { [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactNamePrefixKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactMiddleNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactNameSuffixKey as CNKeyDescriptor,
        CNContactNicknameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactDepartmentNameKey as CNKeyDescriptor,
        CNContactJobTitleKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactPostalAddressesKey as CNKeyDescriptor,
        CNContactBirthdayKey as CNKeyDescriptor,
        CNContactNonGregorianBirthdayKey as CNKeyDescriptor,
        CNContactUrlAddressesKey as CNKeyDescriptor,
        CNContactRelationsKey as CNKeyDescriptor,
        CNContactSocialProfilesKey as CNKeyDescriptor,
        CNContactThumbnailImageDataKey as CNKeyDescriptor,
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
    ] }

    private static func map(_ status: CNAuthorizationStatus) -> ContactAuthorization {
        switch status {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .authorized: .authorized
        case .limited: .limited
        @unknown default: .denied
        }
    }

    static func makeDTO(from contact: CNContact) -> ContactImportDTO {
        let formattedName = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
        let displayName = formattedName.isEmpty
            ? (contact.organizationName.isEmpty ? "Unnamed Contact" : contact.organizationName)
            : formattedName
        let familySort = [contact.familyName, contact.givenName].filter { !$0.isEmpty }.joined(separator: " ")

        return ContactImportDTO(
            sourceIdentifier: contact.identifier,
            givenName: contact.givenName,
            middleName: contact.middleName,
            familyName: contact.familyName,
            namePrefix: contact.namePrefix,
            nameSuffix: contact.nameSuffix,
            nickname: contact.nickname,
            organizationName: contact.organizationName,
            departmentName: contact.departmentName,
            jobTitle: contact.jobTitle,
            displayName: displayName,
            sortName: familySort.isEmpty ? displayName : familySort,
            phoneNumbers: contact.phoneNumbers.map {
                LabeledStringValue(label: localizedLabel($0.label), value: $0.value.stringValue)
            },
            emailAddresses: contact.emailAddresses.map {
                LabeledStringValue(label: localizedLabel($0.label), value: $0.value as String)
            },
            postalAddresses: contact.postalAddresses.map {
                PostalAddressValue(
                    label: localizedLabel($0.label),
                    street: $0.value.street,
                    city: $0.value.city,
                    state: $0.value.state,
                    postalCode: $0.value.postalCode,
                    country: $0.value.country,
                    isoCountryCode: $0.value.isoCountryCode
                )
            },
            birthday: map(contact.birthday),
            nonGregorianBirthday: map(contact.nonGregorianBirthday),
            urlAddresses: contact.urlAddresses.map {
                LabeledStringValue(label: localizedLabel($0.label), value: $0.value as String)
            },
            relationships: contact.contactRelations.map {
                RelationshipValue(label: localizedLabel($0.label), name: $0.value.name)
            },
            socialProfiles: contact.socialProfiles.map {
                SocialProfileValue(
                    label: localizedLabel($0.label),
                    service: $0.value.service,
                    username: $0.value.username,
                    urlString: $0.value.urlString
                )
            },
            thumbnailData: contact.thumbnailImageData
        )
    }

    private static func map(_ components: DateComponents?) -> ContactDateValue? {
        guard let components else { return nil }
        return ContactDateValue(
            year: components.year,
            month: components.month,
            day: components.day,
            calendarIdentifier: components.calendar.map { String(describing: $0.identifier) }
        )
    }

    private static func localizedLabel(_ label: String?) -> String {
        guard let label else { return "Other" }
        return CNLabeledValue<NSString>.localizedString(forLabel: label)
    }
}

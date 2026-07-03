import Foundation
import SwiftData

struct LabeledStringValue: Codable, Hashable, Sendable {
    var label: String
    var value: String
}

struct PostalAddressValue: Codable, Hashable, Sendable {
    var label: String
    var street: String
    var city: String
    var state: String
    var postalCode: String
    var country: String
    var isoCountryCode: String
}

struct ContactDateValue: Codable, Hashable, Sendable {
    var year: Int?
    var month: Int?
    var day: Int?
    var calendarIdentifier: String?
}

struct RelationshipValue: Codable, Hashable, Sendable {
    var label: String
    var name: String
}

struct SocialProfileValue: Codable, Hashable, Sendable {
    var label: String
    var service: String
    var username: String
    var urlString: String
}

enum ContactValueCodec {
    static func encode<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? JSONDecoder().decode(type, from: data)
    }
}

@Model
final class ContactSnapshot {
    @Attribute(.unique) var sourceIdentifier: String
    var givenName: String
    var middleName: String
    var familyName: String
    var namePrefix: String
    var nameSuffix: String
    var nickname: String
    var organizationName: String
    var departmentName: String
    var jobTitle: String
    var displayName: String
    var sortName: String
    var searchText: String
    var phoneValuesData: Data
    var emailValuesData: Data
    var postalAddressValuesData: Data
    var urlValuesData: Data
    var relationshipValuesData: Data
    var socialProfileValuesData: Data
    var birthdayData: Data?
    var nonGregorianBirthdayData: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?
    var synchronizedAt: Date

    init(dto: ContactImportDTO, synchronizedAt: Date) {
        sourceIdentifier = dto.sourceIdentifier
        givenName = dto.givenName
        middleName = dto.middleName
        familyName = dto.familyName
        namePrefix = dto.namePrefix
        nameSuffix = dto.nameSuffix
        nickname = dto.nickname
        organizationName = dto.organizationName
        departmentName = dto.departmentName
        jobTitle = dto.jobTitle
        displayName = dto.displayName
        sortName = dto.sortName
        searchText = dto.searchText
        phoneValuesData = ContactValueCodec.encode(dto.phoneNumbers)
        emailValuesData = ContactValueCodec.encode(dto.emailAddresses)
        postalAddressValuesData = ContactValueCodec.encode(dto.postalAddresses)
        urlValuesData = ContactValueCodec.encode(dto.urlAddresses)
        relationshipValuesData = ContactValueCodec.encode(dto.relationships)
        socialProfileValuesData = ContactValueCodec.encode(dto.socialProfiles)
        birthdayData = dto.birthday.map(ContactValueCodec.encode)
        nonGregorianBirthdayData = dto.nonGregorianBirthday.map(ContactValueCodec.encode)
        thumbnailData = dto.thumbnailData
        self.synchronizedAt = synchronizedAt
    }

    var phoneNumbers: [LabeledStringValue] {
        ContactValueCodec.decode([LabeledStringValue].self, from: phoneValuesData) ?? []
    }

    var emailAddresses: [LabeledStringValue] {
        ContactValueCodec.decode([LabeledStringValue].self, from: emailValuesData) ?? []
    }

    var initials: String {
        let parts = [givenName, familyName].filter { !$0.isEmpty }
        let letters = parts.compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    var subtitle: String? {
        phoneNumbers.first?.value ?? emailAddresses.first?.value
    }

    func matches(search query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let normalizedQuery = query
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        return searchText.contains(normalizedQuery)
    }

    func update(from dto: ContactImportDTO, synchronizedAt: Date) {
        givenName = dto.givenName
        middleName = dto.middleName
        familyName = dto.familyName
        namePrefix = dto.namePrefix
        nameSuffix = dto.nameSuffix
        nickname = dto.nickname
        organizationName = dto.organizationName
        departmentName = dto.departmentName
        jobTitle = dto.jobTitle
        displayName = dto.displayName
        sortName = dto.sortName
        searchText = dto.searchText
        phoneValuesData = ContactValueCodec.encode(dto.phoneNumbers)
        emailValuesData = ContactValueCodec.encode(dto.emailAddresses)
        postalAddressValuesData = ContactValueCodec.encode(dto.postalAddresses)
        urlValuesData = ContactValueCodec.encode(dto.urlAddresses)
        relationshipValuesData = ContactValueCodec.encode(dto.relationships)
        socialProfileValuesData = ContactValueCodec.encode(dto.socialProfiles)
        birthdayData = dto.birthday.map(ContactValueCodec.encode)
        nonGregorianBirthdayData = dto.nonGregorianBirthday.map(ContactValueCodec.encode)
        thumbnailData = dto.thumbnailData
        self.synchronizedAt = synchronizedAt
    }
}

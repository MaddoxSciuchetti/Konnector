import Foundation

struct ContactImportDTO: Hashable, Sendable {
    var sourceIdentifier: String
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
    var phoneNumbers: [LabeledStringValue]
    var emailAddresses: [LabeledStringValue]
    var postalAddresses: [PostalAddressValue]
    var birthday: ContactDateValue?
    var nonGregorianBirthday: ContactDateValue?
    var urlAddresses: [LabeledStringValue]
    var relationships: [RelationshipValue]
    var socialProfiles: [SocialProfileValue]
    var thumbnailData: Data?

    var searchText: String {
        ([displayName, nickname, organizationName]
            + phoneNumbers.map(\.value)
            + emailAddresses.map(\.value))
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

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

    func date(calendar: Calendar = .current) -> Date? {
        guard let month, let day else { return nil }
        var components = DateComponents()
        components.month = month
        components.day = day
        components.year = year ?? calendar.component(.year, from: .now)
        return calendar.date(from: components)
    }
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
    var intelligenceRating: Int = 0
    var integrityRating: Int = 0
    var driveRating: Int = 0
    var badgeRawValue: String = ""
    var note: String = ""
    /// True after the user opens this contact in Konnector for the first time.
    var hasOpenedDetail: Bool = false
    /// True for contacts imported on their first sync; cleared after the initial rating prompt.
    var isNewlyAdded: Bool = false
    /// True once the first-visit rating prompt has been shown and dismissed.
    var hasShownInitialRatingPrompt: Bool = false
    /// Saved LinkedIn profile URL after connecting via QR scan.
    var linkedInProfileURL: String = ""
    /// When the user confirmed a LinkedIn connection for this contact.
    var linkedInConnectedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \ContactVoiceNote.contact)
    var voiceNotes: [ContactVoiceNote] = []
    @Relationship(deleteRule: .cascade, inverse: \ContactCareItem.contact)
    var careItems: [ContactCareItem] = []

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
        if hasPersonalName {
            let parts = [givenName, familyName].filter { !$0.isEmpty }
            let letters = parts.compactMap(\.first).map(String.init).joined()
            if !letters.isEmpty { return letters.uppercased() }
        }

        if !organizationName.isEmpty {
            return String(organizationName.prefix(2)).uppercased()
        }

        return "?"
    }

    var hasPersonalName: Bool {
        ![givenName, middleName, familyName].allSatisfy(\.isEmpty)
    }

    /// Primary label for list rows and navigation. Shows the person's name when available,
    /// otherwise the best available non-name detail. Never pairs a name with a phone number.
    var primaryLabel: String {
        if hasPersonalName {
            return displayName
        }
        return detailLabel
    }

    /// Secondary line text. Omitted when the primary label already carries the contact identity.
    var subtitle: String? {
        nil
    }

    private var detailLabel: String {
        if !organizationName.isEmpty { return organizationName }
        if !jobTitle.isEmpty { return jobTitle }
        if !departmentName.isEmpty { return departmentName }
        if let email = emailAddresses.first?.value, !email.isEmpty { return email }
        if !nickname.isEmpty { return nickname }
        if let relationship = relationships.first?.name, !relationship.isEmpty { return relationship }
        if let username = socialProfiles.first?.username, !username.isEmpty { return username }
        if let url = urlValues.first?.value, !url.isEmpty { return url }
        if let phone = phoneNumbers.first?.value, !phone.isEmpty { return phone }
        return "Unnamed Contact"
    }

    var overallScore: Double {
        Double(intelligenceRating + integrityRating + driveRating) / 3
    }

    var shouldShowInitialRatingPrompt: Bool {
        !hasShownInitialRatingPrompt
    }

    func markDetailOpened() {
        hasOpenedDetail = true
    }

    func completeInitialRatingPrompt() {
        hasShownInitialRatingPrompt = true
        isNewlyAdded = false
    }

    var badges: [ContactBadge] {
        get {
            guard !badgeRawValue.isEmpty else { return [] }
            return badgeRawValue
                .split(separator: ",")
                .compactMap { ContactBadge(rawValue: String($0)) }
        }
        set {
            badgeRawValue = newValue.map(\.rawValue).joined(separator: ",")
        }
    }

    var badgeIDs: [String] {
        get {
            guard !badgeRawValue.isEmpty else { return [] }
            return badgeRawValue
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set {
            badgeRawValue = newValue.joined(separator: ",")
        }
    }

    func hasBadge(_ identifier: String) -> Bool {
        badgeIDs.contains(identifier)
    }

    func badgeDefinitions(from catalog: [BadgeDefinition]) -> [BadgeDefinition] {
        let selected = Set(badgeIDs)
        return catalog
            .filter { selected.contains($0.identifier) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func hasBadge(_ badge: ContactBadge) -> Bool {
        badges.contains(badge)
    }

    var isLinkedInConnected: Bool {
        linkedInConnectedAt != nil
    }

    /// LinkedIn profile URL from synced contact fields, if available.
    var detectedLinkedInProfileURL: String? {
        for profile in socialProfiles where profile.service.localizedCaseInsensitiveContains("linkedin") {
            if let normalized = LinkedInConnectionService.normalizedProfileURL(from: profile.urlString) {
                return normalized
            }
            if let normalized = LinkedInConnectionService.normalizedProfileURL(from: profile.username) {
                return normalized
            }
        }

        for urlValue in urlValues where urlValue.value.localizedCaseInsensitiveContains("linkedin.com") {
            if let normalized = LinkedInConnectionService.normalizedProfileURL(from: urlValue.value) {
                return normalized
            }
        }

        return nil
    }

    func markLinkedInConnected(profileURL: String? = nil) {
        linkedInConnectedAt = .now

        if let profileURL, let normalized = LinkedInConnectionService.normalizedProfileURL(from: profileURL) {
            linkedInProfileURL = normalized
        } else if linkedInProfileURL.isEmpty, let detectedProfileURL = detectedLinkedInProfileURL {
            linkedInProfileURL = detectedProfileURL
        }
    }

    func matches(search query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let normalizedQuery = query
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        return searchText.contains(normalizedQuery)
    }

    /// All filled text fields used for natural-language AI search.
    var aiSearchableText: String {
        var parts: [String] = [
            givenName,
            middleName,
            familyName,
            namePrefix,
            nameSuffix,
            nickname,
            organizationName,
            departmentName,
            jobTitle,
            displayName,
            note
        ]

        parts.append(contentsOf: badgeIDs)
        parts.append(contentsOf: badges.map(\.title))

        parts.append(contentsOf: phoneNumbers.flatMap { [$0.label, $0.value] })
        parts.append(contentsOf: emailAddresses.flatMap { [$0.label, $0.value] })
        parts.append(contentsOf: urlValues.flatMap { [$0.label, $0.value] })
        parts.append(contentsOf: relationships.flatMap { [$0.label, $0.name] })
        parts.append(contentsOf: socialProfiles.flatMap { [$0.label, $0.service, $0.username, $0.urlString] })
        parts.append(linkedInProfileURL)

        for address in postalAddresses {
            parts.append(contentsOf: [
                address.label,
                address.street,
                address.city,
                address.state,
                address.postalCode,
                address.country,
                address.isoCountryCode
            ])
        }

        if let birthday {
            parts.append(formattedBirthday(birthday))
        }
        if let nonGregorianBirthday {
            parts.append(formattedBirthday(nonGregorianBirthday))
        }

        return parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func aiSearchableText(badgeCatalog: [BadgeDefinition]) -> String {
        let badgeTitles = badgeDefinitions(from: badgeCatalog).map(\.title).joined(separator: " ")
        guard !badgeTitles.isEmpty else { return aiSearchableText }
        return aiSearchableText + " " + badgeTitles
    }

    var postalAddresses: [PostalAddressValue] {
        ContactValueCodec.decode([PostalAddressValue].self, from: postalAddressValuesData) ?? []
    }

    var urlValues: [LabeledStringValue] {
        ContactValueCodec.decode([LabeledStringValue].self, from: urlValuesData) ?? []
    }

    var relationships: [RelationshipValue] {
        ContactValueCodec.decode([RelationshipValue].self, from: relationshipValuesData) ?? []
    }

    var socialProfiles: [SocialProfileValue] {
        ContactValueCodec.decode([SocialProfileValue].self, from: socialProfileValuesData) ?? []
    }

    var birthday: ContactDateValue? {
        birthdayData.flatMap { ContactValueCodec.decode(ContactDateValue.self, from: $0) }
    }

    var nonGregorianBirthday: ContactDateValue? {
        nonGregorianBirthdayData.flatMap { ContactValueCodec.decode(ContactDateValue.self, from: $0) }
    }

    private func formattedBirthday(_ value: ContactDateValue) -> String {
        [value.year, value.month, value.day]
            .compactMap { $0 }
            .map(String.init)
            .joined(separator: "-")
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

    func ensureSyncedBirthdayCareItem(in modelContext: ModelContext) {
        guard let birthday = birthday,
              let synced = ContactCareItem.fromSyncedBirthday(birthday) else { return }

        if let existing = careItems.first(where: { $0.kind == .birthday }) {
            existing.month = synced.month
            existing.day = synced.day
            existing.year = synced.year
        } else {
            synced.contact = self
            careItems.append(synced)
            modelContext.insert(synced)
        }
    }
}

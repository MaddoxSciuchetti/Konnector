import Foundation
import SwiftData

enum ContactCareKind: String, Codable, CaseIterable, Identifiable {
    case birthday
    case anniversary
    case appointment
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .birthday: "Birthday"
        case .anniversary: "Anniversary"
        case .appointment: "Appointment"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .birthday: "gift.fill"
        case .anniversary: "heart.fill"
        case .appointment: "calendar.badge.clock"
        case .other: "star.fill"
        }
    }

    var isRecurring: Bool {
        switch self {
        case .birthday, .anniversary: true
        case .appointment, .other: false
        }
    }

    var requiresYear: Bool {
        switch self {
        case .birthday, .anniversary: false
        case .appointment, .other: true
        }
    }
}

@Model
final class ContactCareItem {
    var id: UUID
    var kindRawValue: String
    var customTitle: String
    var month: Int
    var day: Int
    var year: Int?
    var notes: String
    var createdAt: Date
    var contact: ContactSnapshot?

    init(
        kind: ContactCareKind,
        month: Int,
        day: Int,
        year: Int? = nil,
        customTitle: String = "",
        notes: String = "",
        createdAt: Date = .now
    ) {
        id = UUID()
        kindRawValue = kind.rawValue
        self.customTitle = customTitle
        self.month = month
        self.day = day
        self.year = year
        self.notes = notes
        self.createdAt = createdAt
    }

    var kind: ContactCareKind {
        get { ContactCareKind(rawValue: kindRawValue) ?? .other }
        set { kindRawValue = newValue.rawValue }
    }

    var displayTitle: String {
        let trimmed = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return kind.title
    }

    var formattedDate: String {
        Self.formatDate(month: month, day: day, year: year, kind: kind)
    }

    static func formatDate(month: Int, day: Int, year: Int?, kind: ContactCareKind) -> String {
        var components = DateComponents()
        components.month = month
        components.day = day
        if let year {
            components.year = year
        }

        let calendar = Calendar.current
        guard let date = calendar.date(from: components) else {
            return [year, month, day].compactMap { $0 }.map(String.init).joined(separator: "/")
        }

        if kind.requiresYear || year != nil {
            return date.formatted(.dateTime.month(.wide).day().year())
        }
        return date.formatted(.dateTime.month(.wide).day())
    }

    func updateDate(from date: Date, calendar: Calendar = .current) {
        month = calendar.component(.month, from: date)
        day = calendar.component(.day, from: date)
        if kind.requiresYear {
            year = calendar.component(.year, from: date)
        }
    }

    func dateComponents(calendar: Calendar = .current) -> DateComponents {
        var components = DateComponents()
        components.month = month
        components.day = day
        if let year {
            components.year = year
        } else if kind.requiresYear {
            components.year = calendar.component(.year, from: .now)
        }
        return components
    }

    static func fromSyncedBirthday(_ value: ContactDateValue) -> ContactCareItem? {
        guard let month = value.month, let day = value.day else { return nil }
        return ContactCareItem(
            kind: .birthday,
            month: month,
            day: day,
            year: value.year
        )
    }
}

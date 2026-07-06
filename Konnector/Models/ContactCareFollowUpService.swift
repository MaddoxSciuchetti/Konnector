import Foundation

enum ContactCareFollowUpService {
    struct FollowUp: Identifiable {
        var id: UUID { careItem.id }
        let careItem: ContactCareItem
        let contact: ContactSnapshot
        let occurrenceDate: Date
        let daysUntil: Int

        var headline: String {
            switch careItem.kind {
            case .birthday:
                "\(contact.primaryLabel)'s Birthday"
            case .anniversary:
                "\(contact.primaryLabel)'s \(careItem.displayTitle)"
            case .appointment:
                careItem.displayTitle == ContactCareKind.appointment.title
                    ? "Appointment with \(contact.primaryLabel)"
                    : careItem.displayTitle
            case .other:
                careItem.displayTitle
            }
        }

        var detail: String {
            careItem.formattedDate
        }

        var relativeLabel: String {
            switch daysUntil {
            case 0: "Today"
            case 1: "Tomorrow"
            default: "In \(daysUntil) days"
            }
        }
    }

    static func upcomingFollowUps(
        contacts: [ContactSnapshot],
        from referenceDate: Date = .now,
        withinDays: Int = 60,
        calendar: Calendar = .current
    ) -> [FollowUp] {
        let startOfReference = calendar.startOfDay(for: referenceDate)
        var results: [FollowUp] = []

        for contact in contacts {
            for item in contact.careItems {
                guard let occurrenceDate = nextOccurrence(for: item, from: startOfReference, calendar: calendar) else {
                    continue
                }

                let startOfOccurrence = calendar.startOfDay(for: occurrenceDate)
                let daysUntil = calendar.dateComponents([.day], from: startOfReference, to: startOfOccurrence).day ?? 0
                guard daysUntil >= 0, daysUntil <= withinDays else { continue }

                results.append(
                    FollowUp(
                        careItem: item,
                        contact: contact,
                        occurrenceDate: occurrenceDate,
                        daysUntil: daysUntil
                    )
                )
            }
        }

        return results.sorted { lhs, rhs in
            if lhs.occurrenceDate != rhs.occurrenceDate {
                return lhs.occurrenceDate < rhs.occurrenceDate
            }
            return lhs.contact.sortName.localizedCaseInsensitiveCompare(rhs.contact.sortName) == .orderedAscending
        }
    }

    static func nextOccurrence(
        for item: ContactCareItem,
        from referenceDate: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard item.month >= 1, item.month <= 12, item.day >= 1, item.day <= 31 else { return nil }

        if item.kind.isRecurring {
            return nextRecurringOccurrence(
                month: item.month,
                day: item.day,
                from: referenceDate,
                calendar: calendar
            )
        }

        guard let year = item.year else { return nil }
        var components = DateComponents(year: year, month: item.month, day: item.day)
        guard let date = calendar.date(from: components) else { return nil }
        let startOfReference = calendar.startOfDay(for: referenceDate)
        let startOfOccurrence = calendar.startOfDay(for: date)
        guard startOfOccurrence >= startOfReference else { return nil }
        return date
    }

    private static func nextRecurringOccurrence(
        month: Int,
        day: Int,
        from referenceDate: Date,
        calendar: Calendar
    ) -> Date? {
        let referenceYear = calendar.component(.year, from: referenceDate)
        var components = DateComponents(year: referenceYear, month: month, day: day)

        if let date = calendar.date(from: components) {
            let startOfReference = calendar.startOfDay(for: referenceDate)
            let startOfOccurrence = calendar.startOfDay(for: date)
            if startOfOccurrence >= startOfReference {
                return date
            }
        }

        components.year = referenceYear + 1
        return calendar.date(from: components)
    }
}

import SwiftData
import XCTest
@testable import Konnector

@MainActor
final class ContactCareFollowUpTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testRecurringBirthdayReturnsNextOccurrenceThisYear() throws {
        let referenceDate = try makeDate(year: 2026, month: 7, day: 5)
        let item = ContactCareItem(kind: .birthday, month: 12, day: 10, year: 1990)

        let occurrence = ContactCareFollowUpService.nextOccurrence(
            for: item,
            from: referenceDate,
            calendar: calendar
        )

        let expected = try makeDate(year: 2026, month: 12, day: 10)
        XCTAssertEqual(occurrence.map { calendar.startOfDay(for: $0) }, calendar.startOfDay(for: expected))
    }

    func testRecurringBirthdayRollsToNextYearAfterDatePasses() throws {
        let referenceDate = try makeDate(year: 2026, month: 12, day: 11)
        let item = ContactCareItem(kind: .birthday, month: 12, day: 10)

        let occurrence = ContactCareFollowUpService.nextOccurrence(
            for: item,
            from: referenceDate,
            calendar: calendar
        )

        let expected = try makeDate(year: 2027, month: 12, day: 10)
        XCTAssertEqual(occurrence.map { calendar.startOfDay(for: $0) }, calendar.startOfDay(for: expected))
    }

    func testOneTimeAppointmentRequiresFutureDate() throws {
        let referenceDate = try makeDate(year: 2026, month: 7, day: 5)
        let futureItem = ContactCareItem(kind: .appointment, month: 8, day: 1, year: 2026, customTitle: "Check-in")
        let pastItem = ContactCareItem(kind: .appointment, month: 6, day: 1, year: 2026, customTitle: "Past visit")

        let futureOccurrence = ContactCareFollowUpService.nextOccurrence(
            for: futureItem,
            from: referenceDate,
            calendar: calendar
        )
        let pastOccurrence = ContactCareFollowUpService.nextOccurrence(
            for: pastItem,
            from: referenceDate,
            calendar: calendar
        )

        XCTAssertNotNil(futureOccurrence)
        XCTAssertNil(pastOccurrence)
    }

    func testUpcomingFollowUpsSortsSoonestFirst() throws {
        let contact = ContactSnapshot(dto: makeDTO(id: "1", name: "Ada Lovelace"), synchronizedAt: .now)
        let birthday = ContactCareItem(kind: .birthday, month: 8, day: 15)
        birthday.contact = contact
        contact.careItems = [birthday]

        let appointment = ContactCareItem(kind: .appointment, month: 7, day: 20, year: 2026, customTitle: "Lunch")
        appointment.contact = contact
        contact.careItems.append(appointment)

        let referenceDate = try makeDate(year: 2026, month: 7, day: 5)
        let followUps = ContactCareFollowUpService.upcomingFollowUps(
            contacts: [contact],
            from: referenceDate,
            withinDays: 60,
            calendar: calendar
        )

        XCTAssertEqual(followUps.count, 2)
        XCTAssertEqual(followUps.first?.careItem.kind, .appointment)
        XCTAssertEqual(followUps.last?.careItem.kind, .birthday)
    }

    func testFollowUpHeadlineUsesContactNameForBirthday() {
        let contact = ContactSnapshot(dto: makeDTO(id: "1", name: "Ada Lovelace"), synchronizedAt: .now)
        let item = ContactCareItem(kind: .birthday, month: 12, day: 10)
        item.contact = contact

        let followUp = ContactCareFollowUpService.FollowUp(
            careItem: item,
            contact: contact,
            occurrenceDate: .now,
            daysUntil: 3
        )

        XCTAssertEqual(followUp.headline, "Ada Lovelace's Birthday")
    }

    func testEnsureSyncedBirthdayCareItemUpdatesExistingBirthday() throws {
        let container = try inMemoryContainer()
        var dto = makeDTO(id: "1", name: "Ada")
        dto.birthday = ContactDateValue(year: 1815, month: 12, day: 10, calendarIdentifier: "gregorian")
        let contact = ContactSnapshot(dto: dto, synchronizedAt: .now)
        container.mainContext.insert(contact)

        let existing = ContactCareItem(kind: .birthday, month: 1, day: 1)
        existing.contact = contact
        contact.careItems = [existing]
        container.mainContext.insert(existing)

        contact.ensureSyncedBirthdayCareItem(in: container.mainContext)

        XCTAssertEqual(contact.careItems.count, 1)
        XCTAssertEqual(existing.month, 12)
        XCTAssertEqual(existing.day, 10)
        XCTAssertEqual(existing.year, 1815)
    }

    private func inMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: ContactSnapshot.self, ContactCareItem.self, configurations: configuration)
    }

    private func makeDate(year: Int, month: Int, day: Int) throws -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        let date = try XCTUnwrap(calendar.date(from: components))
        return calendar.startOfDay(for: date)
    }
}

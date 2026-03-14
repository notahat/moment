@preconcurrency import EventKit
import Foundation
@testable import MomentCore
import Testing

struct EntryFromEKEventTests {
    let store = EKEventStore()

    func makeEvent(url: URL? = nil) -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.calendar = EKCalendar(for: .event, eventStore: store)
        event.startDate = Date(timeIntervalSinceReferenceDate: 0)
        event.url = url
        return event
    }

    @Test func regularEvent() throws {
        let url = try #require(URL(string: "https://meet.google.com/abc-defg-hij"))
        let entry = Entry(event: makeEvent(url: url), calendarType: .local)
        #expect(entry.type == .event(meetingURL: url, locationURL: nil))
    }

    @Test func birthdayEvent() throws {
        let url = try #require(URL(string: "addressbook://123"))
        let entry = Entry(event: makeEvent(url: url), calendarType: .birthday)
        #expect(entry.type == .birthday(contactURL: url))
    }
}

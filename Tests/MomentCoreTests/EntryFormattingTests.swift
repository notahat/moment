import Foundation
@testable import MomentCore
import Testing

/// Strip ANSI escape codes for easier comparison in tests
private func stripANSI(_ string: String) -> String {
    string.replacing(#/\u{001B}(\][^\u{001B}]*(\u{001B}\\)|\[[0-9;]*m)/#, with: "")
}

private struct Link: Equatable {
    let url: String
    let text: String
}

/// Extract hyperlinks from OSC 8 escape sequences
private func extractLinks(_ string: String) -> [Link] {
    let pattern = #/\u{001B}\]8;;(?<url>[^\u{001B}]*)\u{001B}\\(?<text>[^\u{001B}]*)\u{001B}\]8;;\u{001B}\\/#
    return string.matches(of: pattern).map { Link(url: String($0.url), text: String($0.text)) }
}

struct EntryFormattingTests {
    let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.locale = Locale(identifier: "en_AU")
        return f
    }()

    func makeDate(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 17
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    @Test func timedEvent() {
        let entry = Entry(date: makeDate(hour: 14, minute: 30), isAllDay: false, title: "Team Meeting", type: .event(meetingURL: nil, locationURL: nil))
        let output = stripANSI(renderEntry(entry, timeFormatter: timeFormatter))
        #expect(output == "  2:30 pm  Team Meeting")
    }

    @Test func allDayEvent() {
        let entry = Entry(date: makeDate(hour: 0, minute: 0), isAllDay: true, title: "Public Holiday", type: .event(meetingURL: nil, locationURL: nil))
        let output = stripANSI(renderEntry(entry, timeFormatter: timeFormatter))
        #expect(output == "  All day  Public Holiday")
    }

    @Test func eventWithMeetingURL() throws {
        let url = try #require(URL(string: "https://meet.google.com/abc-defg-hij"))
        let entry = Entry(date: makeDate(hour: 9, minute: 0), isAllDay: false, title: "Standup", type: .event(meetingURL: url, locationURL: nil))
        let output = renderEntry(entry, timeFormatter: timeFormatter)
        #expect(stripANSI(output) == "  9:00 am  Standup [Join]")
        #expect(extractLinks(output) == [Link(url: "https://meet.google.com/abc-defg-hij", text: "[Join]")])
    }

    @Test func eventWithLocation() throws {
        let url = try #require(URL(string: "maps://?q=1+Infinite+Loop"))
        let entry = Entry(date: makeDate(hour: 9, minute: 0), isAllDay: false, title: "Visit", type: .event(meetingURL: nil, locationURL: url))
        let output = renderEntry(entry, timeFormatter: timeFormatter)
        #expect(stripANSI(output) == "  9:00 am  Visit [Map]")
        #expect(extractLinks(output) == [Link(url: "maps://?q=1+Infinite+Loop", text: "[Map]")])
    }

    @Test func reminder() {
        let entry = Entry(date: makeDate(hour: 10, minute: 0), isAllDay: false, title: "Buy milk", type: .reminder(id: "fake-id"))
        let output = stripANSI(renderEntry(entry, timeFormatter: timeFormatter))
        #expect(output == "  10:00 am Buy milk [reminder]")
    }

    @Test func birthdayWithContactURL() throws {
        let url = try #require(URL(string: "addressbook://123"))
        let entry = Entry(date: makeDate(hour: 0, minute: 0), isAllDay: true, title: "Jane Smith's 30th Birthday", type: .birthday(contactURL: url))
        let output = renderEntry(entry, timeFormatter: timeFormatter)
        #expect(stripANSI(output) == "  All day  Jane Smith's 30th Birthday 🎈")
        #expect(extractLinks(output) == [Link(url: "addressbook://123", text: "Jane Smith's 30th Birthday")])
    }

    @Test func birthdayWithoutContactURL() {
        let entry = Entry(date: makeDate(hour: 0, minute: 0), isAllDay: true, title: "Jane Smith's Birthday", type: .birthday(contactURL: nil))
        let output = stripANSI(renderEntry(entry, timeFormatter: timeFormatter))
        #expect(output == "  All day  Jane Smith's Birthday 🎈")
    }
}

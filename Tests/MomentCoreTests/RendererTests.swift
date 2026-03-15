import Foundation
@testable import MomentCore
import Testing

/// Strip ANSI escape codes for easier comparison in tests
private func stripANSI(_ string: String) -> String {
    string
        .replacing(#/\u{001B}(\][^\u{001B}]*(\u{001B}\\)|\[[0-9;]*[mJH])/#, with: "")
        .replacing("\r\n", with: "\n")
}

struct RendererTests {
    let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.locale = Locale(identifier: "en_AU")
        return f
    }()

    let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE d MMM yyyy"
        return f
    }()

    func makeDate(day: Int, hour: Int = 10) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = day
        components.hour = hour
        return Calendar.current.date(from: components)!
    }

    @Test func emptyStateShowsNoEntriesMessage() {
        let state = AppState(entries: [])
        let output = stripANSI(renderAppState(state, dateFormatter: dateFormatter, timeFormatter: timeFormatter))
        #expect(output.contains("No events or reminders in the next 7 days."))
    }

    @Test func selectedEntryHasCursorPrefix() {
        let entry = Entry(date: makeDate(day: 17), isAllDay: false, title: "Buy milk", type: .reminder(id: "r1"))
        let state = AppState(entries: [entry], selectedIndex: 0)
        let output = stripANSI(renderAppState(state, dateFormatter: dateFormatter, timeFormatter: timeFormatter))
        #expect(output.contains("> "))
    }

    @Test func nonSelectedEntryHasSpacePrefix() {
        let entries = [
            Entry(date: makeDate(day: 17), isAllDay: false, title: "Buy milk", type: .reminder(id: "r1")),
            Entry(date: makeDate(day: 17, hour: 11), isAllDay: false, title: "Meeting", type: .event(meetingURL: nil, locationURL: nil)),
        ]
        let state = AppState(entries: entries, selectedIndex: 0)
        let output = stripANSI(renderAppState(state, dateFormatter: dateFormatter, timeFormatter: timeFormatter))
        #expect(output.contains("  11:00 am Meeting"))
    }

    @Test func entriesGroupedByDay() throws {
        let entries = [
            Entry(date: makeDate(day: 17), isAllDay: false, title: "First Day Event", type: .event(meetingURL: nil, locationURL: nil)),
            Entry(date: makeDate(day: 18), isAllDay: false, title: "Second Day Event", type: .event(meetingURL: nil, locationURL: nil)),
        ]
        let state = AppState(entries: entries, selectedIndex: 0)
        let output = stripANSI(renderAppState(state, dateFormatter: dateFormatter, timeFormatter: timeFormatter))
        let firstRange = try #require(output.range(of: "17 Mar 2026"))
        let secondRange = try #require(output.range(of: "18 Mar 2026"))
        #expect(firstRange.lowerBound < secondRange.lowerBound)
        #expect(output.contains("First Day Event"))
        #expect(output.contains("Second Day Event"))
    }
}

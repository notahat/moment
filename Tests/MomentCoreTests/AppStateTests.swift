import Foundation
@testable import MomentCore
import Testing

struct AppStateTests {
    func makeDate(day: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = day
        components.hour = 10
        return Calendar.current.date(from: components)!
    }

    func makeEvent(day: Int = 17) -> Entry {
        Entry(date: makeDate(day: day), isAllDay: false, title: "Meeting", type: .event(meetingURL: nil, locationURL: nil))
    }

    func makeReminder(day: Int = 17, id: String = "reminder-1") -> Entry {
        Entry(date: makeDate(day: day), isAllDay: false, title: "Buy milk", type: .reminder(id: id))
    }

    @Test func movingDownIncreasesSelectedIndex() {
        let state = AppState(entries: [makeEvent(), makeEvent()], selectedIndex: 0)
        let (newState, effects) = handle(key: .down, state: state)
        #expect(newState.selectedIndex == 1)
        #expect(effects == [])
    }

    @Test func movingUpDecreasesSelectedIndex() {
        let state = AppState(entries: [makeEvent(), makeEvent()], selectedIndex: 1)
        let (newState, effects) = handle(key: .up, state: state)
        #expect(newState.selectedIndex == 0)
        #expect(effects == [])
    }

    @Test func selectedIndexClampsAtBoundaries() {
        let entries = [makeEvent(), makeEvent()]
        let stateAtStart = AppState(entries: entries, selectedIndex: 0)
        let (newStateUp, _) = handle(key: .up, state: stateAtStart)
        #expect(newStateUp.selectedIndex == 0)

        let stateAtEnd = AppState(entries: entries, selectedIndex: 1)
        let (newStateDown, _) = handle(key: .down, state: stateAtEnd)
        #expect(newStateDown.selectedIndex == 1)
    }

    @Test func enterOnReminderRemovesItAndRequestsCompletion() {
        let state = AppState(entries: [makeReminder(id: "r1"), makeEvent()], selectedIndex: 0)
        let (newState, effects) = handle(key: .enter, state: state)
        #expect(newState.entries.count == 1)
        #expect(effects == [.completeReminder(id: "r1")])
    }

    @Test func enterOnReminderWhenLastEntryAlsoRequestsExit() {
        let state = AppState(entries: [makeReminder(id: "r1")], selectedIndex: 0)
        let (newState, effects) = handle(key: .enter, state: state)
        #expect(newState.entries.isEmpty)
        #expect(effects == [.completeReminder(id: "r1"), .exit])
    }

    @Test func enterOnEventDoesNothing() {
        let state = AppState(entries: [makeEvent(), makeReminder()], selectedIndex: 0)
        let (newState, effects) = handle(key: .enter, state: state)
        #expect(newState == state)
        #expect(effects == [])
    }

    @Test func quitReturnsExitEffect() {
        let state = AppState(entries: [makeEvent()], selectedIndex: 0)
        let (newState, effects) = handle(key: .quit, state: state)
        #expect(newState == state)
        #expect(effects == [.exit])
    }
}

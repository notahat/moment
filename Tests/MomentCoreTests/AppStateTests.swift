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

    @Test func enterOnLastReminderLeavesEntriesEmpty() {
        let state = AppState(entries: [makeReminder(id: "r1")], selectedIndex: 0)
        let (newState, effects) = handle(key: .enter, state: state)
        #expect(newState.entries.isEmpty)
        #expect(effects == [.completeReminder(id: "r1")])
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

    // MARK: - Undo

    @Test func completingReminderPushesToUndoStack() {
        let reminder = makeReminder(id: "r1")
        let state = AppState(entries: [reminder, makeEvent()], selectedIndex: 0)
        let (newState, _) = handle(key: .enter, state: state)
        #expect(newState.undoStack == [.reminderCompleted(entry: reminder, atIndex: 0)])
    }

    @Test func undoWithEmptyStackIsNoOp() {
        let state = AppState(entries: [makeEvent()])
        let (newState, effects) = handle(key: .undo, state: state)
        #expect(newState == state)
        #expect(effects == [])
    }

    @Test func undoReInsertsEntryAtOriginalIndex() {
        let reminder = makeReminder(id: "r1")
        let event = makeEvent()
        var state = AppState(entries: [reminder, event], selectedIndex: 0)
        (state, _) = handle(key: .enter, state: state)
        let (newState, _) = handle(key: .undo, state: state)
        #expect(newState.entries == [reminder, event])
        #expect(newState.selectedIndex == 0)
        #expect(newState.undoStack.isEmpty)
    }

    @Test func undoEmitsUncompleteReminderEffect() {
        var state = AppState(entries: [makeReminder(id: "r1"), makeEvent()], selectedIndex: 0)
        (state, _) = handle(key: .enter, state: state)
        let (_, effects) = handle(key: .undo, state: state)
        #expect(effects == [.uncompleteReminder(id: "r1")])
    }

    @Test func multipleCompletionsThenUndoInReverseOrder() {
        let r1 = makeReminder(day: 17, id: "r1")
        let r2 = makeReminder(day: 18, id: "r2")
        var state = AppState(entries: [r1, r2], selectedIndex: 0)
        (state, _) = handle(key: .enter, state: state) // complete r1
        (state, _) = handle(key: .enter, state: state) // complete r2
        #expect(state.undoStack.count == 2)

        var effects: [Effect]
        (state, effects) = handle(key: .undo, state: state) // undo r2
        #expect(state.entries == [r2])
        #expect(effects == [.uncompleteReminder(id: "r2")])

        (state, effects) = handle(key: .undo, state: state) // undo r1
        #expect(state.entries == [r1, r2])
        #expect(effects == [.uncompleteReminder(id: "r1")])
        #expect(state.undoStack.isEmpty)
    }

    @Test func completeUndoCompleteAgainIsCorrect() {
        let reminder = makeReminder(id: "r1")
        var state = AppState(entries: [reminder, makeEvent()], selectedIndex: 0)
        var effects: [Effect]
        (state, effects) = handle(key: .enter, state: state)
        #expect(effects == [.completeReminder(id: "r1")])
        (state, effects) = handle(key: .undo, state: state)
        #expect(effects == [.uncompleteReminder(id: "r1")])
        (state, effects) = handle(key: .enter, state: state)
        #expect(effects == [.completeReminder(id: "r1")])
        #expect(state.undoStack.count == 1)
    }
}

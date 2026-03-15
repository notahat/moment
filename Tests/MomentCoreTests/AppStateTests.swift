import Foundation
@testable import MomentCore
import Testing

struct AppStateTests {
    func makeDate(day: Int, hour: Int = 10) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = day
        components.hour = hour
        return Calendar.current.date(from: components)!
    }

    func makeEvent(day: Int = 17, id: String = "event-1") -> Entry {
        Entry(id: id, date: makeDate(day: day, hour: 11), isAllDay: false, title: "Meeting", type: .event(meetingURL: nil, locationURL: nil))
    }

    func makeReminder(day: Int = 17, id: String = "reminder-1") -> Entry {
        Entry(id: id, date: makeDate(day: day, hour: 10), isAllDay: false, title: "Buy milk", type: .reminder(id: id))
    }

    @Test func movingDownIncreasesSelectedIndex() {
        let e1 = makeEvent(id: "e1")
        let e2 = makeEvent(id: "e2")
        let state = AppState(entries: [e1, e2])
        let (newState, effects) = state.handle(key: .down)
        #expect(newState.selectedID == "e2")
        #expect(effects == [])
    }

    @Test func movingUpDecreasesSelectedIndex() {
        let e1 = makeEvent(id: "e1")
        let e2 = makeEvent(id: "e2")
        let state = AppState(entries: [e1, e2], selectedID: "e2")
        let (newState, effects) = state.handle(key: .up)
        #expect(newState.selectedID == "e1")
        #expect(effects == [])
    }

    @Test func selectedIndexClampsAtBoundaries() {
        let e1 = makeEvent(id: "e1")
        let e2 = makeEvent(id: "e2")
        let entries = [e1, e2]

        let stateAtStart = AppState(entries: entries)
        let (newStateUp, _) = stateAtStart.handle(key: .up)
        #expect(newStateUp.selectedID == "e1")

        let stateAtEnd = AppState(entries: entries, selectedID: "e2")
        let (newStateDown, _) = stateAtEnd.handle(key: .down)
        #expect(newStateDown.selectedID == "e2")
    }

    @Test func enterOnReminderRemovesItAndRequestsCompletion() {
        let state = AppState(entries: [makeReminder(id: "r1"), makeEvent(id: "e1")])
        let (newState, effects) = state.handle(key: .enter)
        #expect(newState.entries.count == 1)
        #expect(effects == [.completeReminder(id: "r1")])
    }

    @Test func enterOnLastReminderLeavesEntriesEmpty() {
        let state = AppState(entries: [makeReminder(id: "r1")])
        let (newState, effects) = state.handle(key: .enter)
        #expect(newState.entries.isEmpty)
        #expect(effects == [.completeReminder(id: "r1")])
    }

    @Test func enterOnEventDoesNothing() {
        let state = AppState(entries: [makeEvent(id: "e1"), makeReminder()])
        let (newState, effects) = state.handle(key: .enter)
        #expect(newState == state)
        #expect(effects == [])
    }

    @Test func quitReturnsExitEffect() {
        let state = AppState(entries: [makeEvent(id: "e1")])
        let (newState, effects) = state.handle(key: .quit)
        #expect(newState == state)
        #expect(effects == [.exit])
    }

    // MARK: - Undo

    @Test func completingReminderPushesToUndoStack() {
        let reminder = makeReminder(id: "r1")
        let state = AppState(entries: [reminder, makeEvent(id: "e1")])
        let (newState, _) = state.handle(key: .enter)
        #expect(newState.undoStack == [.reminderCompleted(entry: reminder)])
    }

    @Test func undoWithEmptyStackIsNoOp() {
        let state = AppState(entries: [makeEvent(id: "e1")])
        let (newState, effects) = state.handle(key: .undo)
        #expect(newState == state)
        #expect(effects == [])
    }

    @Test func undoReInsertsEntryAtOriginalIndex() {
        let reminder = makeReminder(id: "r1") // hour 10
        let event = makeEvent(id: "e1") // hour 11 — sorts after reminder
        var state = AppState(entries: [reminder, event])
        (state, _) = state.handle(key: .enter)
        let (newState, _) = state.handle(key: .undo)
        #expect(newState.entries == [reminder, event])
        #expect(newState.selectedID == "r1")
        #expect(newState.undoStack.isEmpty)
    }

    @Test func undoEmitsUncompleteReminderEffect() {
        var state = AppState(entries: [makeReminder(id: "r1"), makeEvent(id: "e1")])
        (state, _) = state.handle(key: .enter)
        let (_, effects) = state.handle(key: .undo)
        #expect(effects == [.uncompleteReminder(id: "r1")])
    }

    @Test func multipleCompletionsThenUndoInReverseOrder() {
        let r1 = makeReminder(day: 17, id: "r1")
        let r2 = makeReminder(day: 18, id: "r2")
        var state = AppState(entries: [r1, r2])
        (state, _) = state.handle(key: .enter) // complete r1
        (state, _) = state.handle(key: .enter) // complete r2
        #expect(state.undoStack.count == 2)

        var effects: [Effect]
        (state, effects) = state.handle(key: .undo) // undo r2
        #expect(state.entries == [r2])
        #expect(effects == [.uncompleteReminder(id: "r2")])

        (state, effects) = state.handle(key: .undo) // undo r1
        #expect(state.entries == [r1, r2])
        #expect(effects == [.uncompleteReminder(id: "r1")])
        #expect(state.undoStack.isEmpty)
    }

    @Test func completeUndoCompleteAgainIsCorrect() {
        let reminder = makeReminder(id: "r1")
        var state = AppState(entries: [reminder, makeEvent(id: "e1")])
        var effects: [Effect]
        (state, effects) = state.handle(key: .enter)
        #expect(effects == [.completeReminder(id: "r1")])
        (state, effects) = state.handle(key: .undo)
        #expect(effects == [.uncompleteReminder(id: "r1")])
        (state, effects) = state.handle(key: .enter)
        #expect(effects == [.completeReminder(id: "r1")])
        #expect(state.undoStack.count == 1)
    }
}

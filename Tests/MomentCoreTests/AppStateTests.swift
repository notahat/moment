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

    // MARK: - Navigation

    @Test func moveUpDecreasesSelectedIndex() {
        let e1 = makeEvent(id: "e1")
        let e2 = makeEvent(id: "e2")
        let state = AppState(entries: [e1, e2], selectedID: "e2")
        #expect(state.moveUp().selectedID == "e1")
    }

    @Test func moveDownIncreasesSelectedIndex() {
        let e1 = makeEvent(id: "e1")
        let e2 = makeEvent(id: "e2")
        let state = AppState(entries: [e1, e2])
        #expect(state.moveDown().selectedID == "e2")
    }

    @Test func moveUpClampsAtTop() {
        let e1 = makeEvent(id: "e1")
        let e2 = makeEvent(id: "e2")
        let state = AppState(entries: [e1, e2])
        #expect(state.moveUp().selectedID == "e1")
    }

    @Test func moveDownClampsAtBottom() {
        let e1 = makeEvent(id: "e1")
        let e2 = makeEvent(id: "e2")
        let state = AppState(entries: [e1, e2], selectedID: "e2")
        #expect(state.moveDown().selectedID == "e2")
    }

    // MARK: - Complete Reminder

    @Test func completeReminderRemovesItFromEntries() {
        let state = AppState(entries: [makeReminder(id: "r1"), makeEvent(id: "e1")])
        let newState = state.completeReminder(id: "r1")
        #expect(newState.entries.count == 1)
        #expect(newState.entries[0].id == "e1")
    }

    @Test func completeReminderPushesToUndoStack() {
        let reminder = makeReminder(id: "r1")
        let state = AppState(entries: [reminder, makeEvent(id: "e1")])
        let newState = state.completeReminder(id: "r1")
        #expect(newState.undoStack == [.reminderCompleted(entry: reminder)])
    }

    @Test func completeLastReminderLeavesEntriesEmpty() {
        let state = AppState(entries: [makeReminder(id: "r1")])
        let newState = state.completeReminder(id: "r1")
        #expect(newState.entries.isEmpty)
    }

    // MARK: - Add Reminder

    @Test func startAddReminderEntersAddingMode() {
        let state = AppState(entries: [makeEvent(id: "e1")])
        #expect(state.startAddReminder().mode == .addingReminder(text: ""))
    }

    @Test func cancelAddReminderReturnsToBrowsing() {
        let state = AppState(entries: [], mode: .addingReminder(text: "Hello"))
        #expect(state.cancelAddReminder().mode == .browsing)
    }

    @Test func appendCharacterAddsToText() {
        let state = AppState(entries: [], mode: .addingReminder(text: "He"))
        #expect(state.appendCharacter("y").mode == .addingReminder(text: "Hey"))
    }

    @Test func deleteLastCharacterRemovesFromText() {
        let state = AppState(entries: [], mode: .addingReminder(text: "Hey"))
        #expect(state.deleteLastCharacter().mode == .addingReminder(text: "He"))
    }

    @Test func addReminderInsertsEntryAndSelectsIt() {
        let event = makeEvent(id: "e1") // hour 11
        let state = AppState(entries: [event])
        let reminder = makeReminder(id: "r-new") // hour 10 — sorts before event
        let newState = state.addReminder(entry: reminder)
        #expect(newState.entries == [reminder, event])
        #expect(newState.selectedID == "r-new")
        #expect(newState.undoStack == [.reminderAdded(id: "r-new")])
        #expect(newState.mode == .browsing)
    }

    // MARK: - Undo

    @Test func undoCompleteReminderReInsertsEntryAtOriginalPosition() {
        let reminder = makeReminder(id: "r1") // hour 10
        let event = makeEvent(id: "e1") // hour 11 — sorts after reminder
        let state = AppState(entries: [reminder, event])
        let afterComplete = state.completeReminder(id: "r1")
        let afterUndo = afterComplete.undoCompleteReminder(entry: reminder)
        #expect(afterUndo.entries == [reminder, event])
        #expect(afterUndo.selectedID == "r1")
        #expect(afterUndo.undoStack.isEmpty)
    }

    @Test func undoAddReminderRemovesItFromEntries() {
        let reminder = makeReminder(id: "r1")
        let event = makeEvent(id: "e1")
        var state = AppState(entries: [event])
        state = state.addReminder(entry: reminder)
        let newState = state.undoAddReminder(id: "r1")
        #expect(!newState.entries.contains(where: { $0.id == "r1" }))
        #expect(newState.undoStack.isEmpty)
    }

    @Test func multipleCompletionsThenUndoInReverseOrder() {
        let r1 = makeReminder(day: 17, id: "r1")
        let r2 = makeReminder(day: 18, id: "r2")
        var state = AppState(entries: [r1, r2])
        state = state.completeReminder(id: "r1")
        state = state.completeReminder(id: "r2")
        #expect(state.undoStack.count == 2)

        state = state.undoCompleteReminder(entry: r2)
        #expect(state.entries == [r2])
        #expect(state.undoStack.count == 1)

        state = state.undoCompleteReminder(entry: r1)
        #expect(state.entries == [r1, r2])
        #expect(state.undoStack.isEmpty)
    }
}

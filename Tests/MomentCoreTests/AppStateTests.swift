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

    func makeEventSnapshot(day: Int = 17, id: String = "event-1") -> EventSnapshot {
        EventSnapshot(
            id: id,
            title: "Meeting",
            startDate: makeDate(day: day, hour: 11),
            endDate: makeDate(day: day, hour: 12),
            isAllDay: false,
            calendarIdentifier: "calendar-1",
            location: nil,
            notes: nil,
            url: nil,
        )
    }

    func makeSnapshot(day: Int = 17, id: String = "reminder-1") -> ReminderSnapshot {
        ReminderSnapshot(
            id: id,
            title: "Buy milk",
            date: makeDate(day: day, hour: 10),
            calendarIdentifier: "calendar-1",
            notes: nil,
            priority: 0,
            dueDateComponents: nil,
            url: nil,
        )
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

    // MARK: - Initialisation

    @Test func initWithInvalidSelectedIDDefaultsToFirst() {
        let e1 = makeEvent(id: "e1")
        let e2 = makeEvent(id: "e2")
        let state = AppState(entries: [e1, e2], selectedID: "nonexistent")
        #expect(state.selectedID == "e1")
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

    @Test func completeSelectedReminderMovesSelectionToNextEntry() {
        let r1 = makeReminder(id: "r1") // hour 10 — sorts before event
        let e1 = makeEvent(id: "e1") // hour 11
        let state = AppState(entries: [r1, e1], selectedID: "r1")
        #expect(state.completeReminder(id: "r1").selectedID == "e1")
    }

    @Test func completeSelectedReminderMovesSelectionToPreviousWhenLast() {
        let e1 = makeEvent(id: "e1") // day 17
        let r1 = makeReminder(day: 18, id: "r1") // day 18 — sorts after e1
        let state = AppState(entries: [e1, r1], selectedID: "r1")
        #expect(state.completeReminder(id: "r1").selectedID == "e1")
    }

    @Test func completeLastReminderLeavesEntriesEmpty() {
        let state = AppState(entries: [makeReminder(id: "r1")])
        let newState = state.completeReminder(id: "r1")
        #expect(newState.entries.isEmpty)
    }

    // MARK: - Add Reminder

    @Test func startAddReminderEntersAddingMode() {
        let state = AppState(entries: [makeEvent(id: "e1")])
        #expect(state.startAddReminder().mode == .addingReminder(editor: LineEditor()))
    }

    @Test func cancelAddReminderReturnsToBrowsing() {
        let state = AppState(entries: [], mode: .addingReminder(editor: LineEditor(text: "Hello")))
        #expect(state.cancelAddReminder().mode == .browsing)
    }

    @Test func insertCharacterAddsToText() {
        let state = AppState(entries: [], mode: .addingReminder(editor: LineEditor(text: "He")))
        guard case let .addingReminder(editor) = state.insertCharacter("y").mode else { return }
        #expect(editor.text == "Hey")
    }

    @Test func deleteBackwardRemovesFromText() {
        let state = AppState(entries: [], mode: .addingReminder(editor: LineEditor(text: "Hey")))
        guard case let .addingReminder(editor) = state.deleteBackward().mode else { return }
        #expect(editor.text == "He")
    }

    @Test func addReminderInsertsEntryAndSelectsIt() {
        let event = makeEvent(id: "e1") // hour 11
        let state = AppState(entries: [event])
        let reminder = makeReminder(id: "r-new") // hour 10 — sorts before event
        let newState = state.addReminder(entry: reminder)
        #expect(newState.entries == [reminder, event])
        #expect(newState.selectedID == "r-new")
        #expect(newState.undoStack == [.reminderAdded(entry: reminder)])
        #expect(newState.mode == .browsing)
    }

    // MARK: - Delete Reminder

    @Test func deleteReminderRemovesItFromEntries() {
        let state = AppState(entries: [makeReminder(id: "r1"), makeEvent(id: "e1")])
        let newState = state.deleteReminder(snapshot: makeSnapshot(id: "r1"))
        #expect(newState.entries.count == 1)
        #expect(newState.entries[0].id == "e1")
    }

    @Test func deleteReminderPushesToUndoStack() {
        let snapshot = makeSnapshot(id: "r1")
        let state = AppState(entries: [makeReminder(id: "r1"), makeEvent(id: "e1")])
        let newState = state.deleteReminder(snapshot: snapshot)
        #expect(newState.undoStack == [.reminderDeleted(snapshot: snapshot)])
    }

    // MARK: - Delete Event

    @Test func deleteEventRemovesItFromEntries() {
        let snapshot = makeEventSnapshot(id: "e1")
        let state = AppState(entries: [snapshot.entry, makeReminder(id: "r1")])
        let newState = state.deleteEvent(snapshot: snapshot)
        #expect(newState.entries.count == 1)
        #expect(newState.entries[0].id == "r1")
    }

    @Test func deleteEventPushesToUndoStack() {
        let snapshot = makeEventSnapshot(id: "e1")
        let state = AppState(entries: [snapshot.entry, makeReminder(id: "r1")])
        let newState = state.deleteEvent(snapshot: snapshot)
        #expect(newState.undoStack == [.eventDeleted(snapshot: snapshot)])
    }

    @Test func undoDeleteEventReInsertsEntryAtOriginalPosition() {
        let snapshot = makeEventSnapshot(id: "e1") // hour 11
        let reminder = makeReminder(id: "r1") // hour 10 — sorts before event
        let state = AppState(entries: [reminder, snapshot.entry])
        let afterDelete = state.deleteEvent(snapshot: snapshot)
        let afterUndo = afterDelete.undoDeleteEvent(snapshot: snapshot)
        #expect(afterUndo.entries == [reminder, snapshot.entry])
        #expect(afterUndo.selectedID == "e1")
        #expect(afterUndo.undoStack.isEmpty)
    }

    @Test func redoDeleteEventRemovesItFromEntries() {
        let snapshot = makeEventSnapshot(id: "e1")
        let reminder = makeReminder(id: "r1")
        var state = AppState(entries: [reminder, snapshot.entry])
        state = state.deleteEvent(snapshot: snapshot)
        state = state.undoDeleteEvent(snapshot: snapshot)
        let afterRedo = state.redoDeleteEvent(snapshot: snapshot)
        #expect(!afterRedo.entries.contains(where: { $0.id == "e1" }))
        #expect(afterRedo.undoStack == [.eventDeleted(snapshot: snapshot)])
        #expect(afterRedo.redoStack.isEmpty)
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
        let newState = state.undoAddReminder(entry: reminder)
        #expect(!newState.entries.contains(where: { $0.id == "r1" }))
        #expect(newState.undoStack.isEmpty)
    }

    // MARK: - Redo

    @Test func redoCompleteReminderRemovesItFromEntries() {
        let reminder = makeReminder(id: "r1")
        let event = makeEvent(id: "e1")
        var state = AppState(entries: [reminder, event])
        state = state.completeReminder(id: "r1")
        state = state.undoCompleteReminder(entry: reminder)
        let afterRedo = state.redoCompleteReminder(entry: reminder)
        #expect(!afterRedo.entries.contains(where: { $0.id == "r1" }))
        #expect(afterRedo.undoStack == [.reminderCompleted(entry: reminder)])
        #expect(afterRedo.redoStack.isEmpty)
    }

    @Test func redoAddReminderReInsertsEntry() {
        let reminder = makeReminder(id: "r1")
        let event = makeEvent(id: "e1")
        var state = AppState(entries: [event])
        state = state.addReminder(entry: reminder)
        state = state.undoAddReminder(entry: reminder)
        let afterRedo = state.redoAddReminder(entry: reminder)
        #expect(afterRedo.entries.contains(where: { $0.id == "r1" }))
        #expect(afterRedo.undoStack == [.reminderAdded(entry: reminder)])
        #expect(afterRedo.redoStack.isEmpty)
    }

    @Test func undoDeleteReminderReInsertsEntryAtOriginalPosition() {
        let snapshot = makeSnapshot(id: "r1") // hour 10
        let event = makeEvent(id: "e1") // hour 11 — sorts after reminder
        let state = AppState(entries: [snapshot.entry, event])
        let afterDelete = state.deleteReminder(snapshot: snapshot)
        let afterUndo = afterDelete.undoDeleteReminder(snapshot: snapshot)
        #expect(afterUndo.entries == [snapshot.entry, event])
        #expect(afterUndo.selectedID == "r1")
        #expect(afterUndo.undoStack.isEmpty)
    }

    @Test func redoDeleteReminderRemovesItFromEntries() {
        let snapshot = makeSnapshot(id: "r1")
        let event = makeEvent(id: "e1")
        var state = AppState(entries: [snapshot.entry, event])
        state = state.deleteReminder(snapshot: snapshot)
        state = state.undoDeleteReminder(snapshot: snapshot)
        let afterRedo = state.redoDeleteReminder(snapshot: snapshot)
        #expect(!afterRedo.entries.contains(where: { $0.id == "r1" }))
        #expect(afterRedo.undoStack == [.reminderDeleted(snapshot: snapshot)])
        #expect(afterRedo.redoStack.isEmpty)
    }

    @Test func undoThenNewActionClearsRedoStack() {
        let r1 = makeReminder(day: 17, id: "r1")
        let r2 = makeReminder(day: 18, id: "r2")
        var state = AppState(entries: [r1, r2])
        state = state.completeReminder(id: "r1")
        state = state.undoCompleteReminder(entry: r1)
        #expect(!state.redoStack.isEmpty)
        state = state.completeReminder(id: "r2")
        #expect(state.redoStack.isEmpty)
    }

    @Test func redoStackPreservedThroughUndoRedo() {
        let r1 = makeReminder(day: 17, id: "r1")
        let r2 = makeReminder(day: 18, id: "r2")
        var state = AppState(entries: [r1, r2])
        state = state.completeReminder(id: "r1")
        state = state.completeReminder(id: "r2")
        state = state.undoCompleteReminder(entry: r2)
        state = state.undoCompleteReminder(entry: r1)
        #expect(state.redoStack.count == 2)
        state = state.redoCompleteReminder(entry: r1)
        #expect(state.redoStack.count == 1)
        #expect(state.undoStack == [.reminderCompleted(entry: r1)])
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

// @preconcurrency suppresses Swift 6 Sendable errors for EventKit types that predate strict concurrency.
@preconcurrency import EventKit
import Foundation
import MomentCore

/// Coordinates user input with EventKit and app state for a single TUI session.
///
/// Session owns the `EKEventStore` and `AppState`. Each user action is handled by a
/// private method that performs any necessary EventKit work, then calls a pure
/// transformation method on `AppState` to update state optimistically.
struct Session {
    private let store: EKEventStore

    /// The current UI state. Updated immediately on every user action (optimistic updates).
    private(set) var state: AppState

    init(store: EKEventStore, entries: [Entry]) {
        self.store = store
        state = AppState(entries: entries)
    }

    /// Handles a keypress. Returns `true` if the app should exit.
    mutating func handle(key: RawTerminal.Key) -> Bool {
        switch state.mode {
        case .browsing: handleBrowsingKey(key)
        case .addingReminder: handleAddingKey(key)
        }
    }

    /// Rebuilds state from a fresh EventKit fetch, preserving selection, undo stack, and redo stack.
    mutating func refresh(entries: [Entry]) {
        state = AppState(entries: entries, selectedID: state.selectedID, undoStack: state.undoStack, redoStack: state.redoStack)
    }

    private mutating func handleBrowsingKey(_ key: RawTerminal.Key) -> Bool {
        switch key {
        case .up: state = state.moveUp(); return false
        case .down: state = state.moveDown(); return false
        case .enter: completeSelectedReminder(); return false
        case let .character(c):
            switch c {
            case "q", "\u{03}": return true
            case "u": undo(); return false
            case "r": redo(); return false
            case "k": state = state.moveUp(); return false
            case "j": state = state.moveDown(); return false
            case "n": state = state.startAddReminder(); return false
            case "d": deleteSelectedReminder(); return false
            default: return false
            }
        default: return false
        }
    }

    private mutating func handleAddingKey(_ key: RawTerminal.Key) -> Bool {
        switch key {
        case .escape: state = state.cancelAddReminder()
        case .enter:
            guard case let .addingReminder(editor) = state.mode, !editor.text.isEmpty else { break }
            addReminder(title: editor.text)
        case .backspace: state = state.deleteBackward()
        case .left: state = state.moveCursorLeft()
        case .right: state = state.moveCursorRight()
        case .lineStart: state = state.moveCursorToStart()
        case .lineEnd: state = state.moveCursorToEnd()
        case .deleteToEnd: state = state.deleteToEnd()
        case .deleteWordBackward: state = state.deleteWordBackward()
        case let .character(c): state = state.insertCharacter(c)
        default: break
        }
        return false
    }

    private mutating func completeSelectedReminder() {
        guard let entry = state.selectedEntry, case let .reminder(id) = entry.type else { return }
        state = state.completeReminder(id: id)
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        reminder.isCompleted = true
        do { try store.save(reminder, commit: true) } catch {
            print("\nFailed to complete reminder: \(error)")
        }
    }

    private mutating func deleteSelectedReminder() {
        guard let entry = state.selectedEntry, case let .reminder(id) = entry.type else { return }
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        let snapshot = ReminderSnapshot(reminder: reminder, date: entry.date)
        state = state.deleteReminder(snapshot: snapshot)
        do { try store.remove(reminder, commit: true) } catch {
            print("\nFailed to delete reminder: \(error)")
        }
    }

    private mutating func addReminder(title: String) {
        guard let entry = createEKReminder(title: title, date: Date()) else { return }
        state = state.addReminder(entry: entry)
    }

    private func createEKReminder(title: String, date: Date) -> Entry? {
        let dueDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let snapshot = ReminderSnapshot(
            id: "",
            title: title,
            date: date,
            calendarIdentifier: store.defaultCalendarForNewReminders()?.calendarIdentifier ?? "",
            notes: nil,
            priority: 0,
            dueDateComponents: dueDateComponents,
            url: nil,
        )
        return recreateEKReminder(from: snapshot)?.entry
    }

    /// Creates a new EKReminder from a snapshot and returns an updated snapshot with the new identifier.
    /// Returns `nil` if the reminder could not be saved.
    private func recreateEKReminder(from snapshot: ReminderSnapshot) -> ReminderSnapshot? {
        let reminder = EKReminder(eventStore: store)
        reminder.title = snapshot.title
        reminder.notes = snapshot.notes
        reminder.priority = snapshot.priority
        reminder.dueDateComponents = snapshot.dueDateComponents
        reminder.url = snapshot.url
        let calendar = store.calendar(withIdentifier: snapshot.calendarIdentifier)
            ?? store.defaultCalendarForNewReminders()
        guard let calendar else { return nil }
        reminder.calendar = calendar
        do { try store.save(reminder, commit: true) } catch {
            print("\nFailed to recreate reminder: \(error)")
            return nil
        }
        let resolvedDate = snapshot.dueDateComponents.flatMap {
            Calendar.current.date(from: $0)
        } ?? snapshot.date
        return ReminderSnapshot(reminder: reminder, date: resolvedDate)
    }

    private mutating func undo() {
        guard let action = state.undoStack.last else { return }
        switch action {
        case let .reminderCompleted(entry):
            guard case let .reminder(id) = entry.type else { return }
            state = state.undoCompleteReminder(entry: entry)
            guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
            reminder.isCompleted = false
            do { try store.save(reminder, commit: true) } catch {
                print("\nFailed to uncomplete reminder: \(error)")
            }
        case let .reminderAdded(entry):
            guard case let .reminder(id) = entry.type else { return }
            state = state.undoAddReminder(entry: entry)
            guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
            do { try store.remove(reminder, commit: true) } catch {
                print("\nFailed to delete reminder: \(error)")
            }
        case let .reminderDeleted(snapshot):
            guard let restoredSnapshot = recreateEKReminder(from: snapshot) else { return }
            state = state.undoDeleteReminder(snapshot: restoredSnapshot)
        }
    }

    private mutating func redo() {
        guard let action = state.redoStack.last else { return }
        switch action {
        case let .reminderCompleted(entry):
            guard case let .reminder(id) = entry.type else { return }
            state = state.redoCompleteReminder(entry: entry)
            guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
            reminder.isCompleted = true
            do { try store.save(reminder, commit: true) } catch {
                print("\nFailed to complete reminder: \(error)")
            }
        case let .reminderAdded(entry):
            guard let newEntry = createEKReminder(title: entry.title, date: entry.date) else { return }
            state = state.redoAddReminder(entry: newEntry)
        case let .reminderDeleted(snapshot):
            state = state.redoDeleteReminder(snapshot: snapshot)
            guard let reminder = store.calendarItem(withIdentifier: snapshot.id) as? EKReminder else { return }
            do { try store.remove(reminder, commit: true) } catch {
                print("\nFailed to delete reminder: \(error)")
            }
        }
    }
}

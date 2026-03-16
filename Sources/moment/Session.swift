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
        case let .addingReminder(text): handleAddingKey(key, text: text)
        }
    }

    /// Rebuilds state from a fresh EventKit fetch, preserving selection and undo stack.
    mutating func refresh(entries: [Entry]) {
        state = AppState(entries: entries, selectedID: state.selectedID, undoStack: state.undoStack)
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
            case "k": state = state.moveUp(); return false
            case "j": state = state.moveDown(); return false
            case "n": state = state.startAddReminder(); return false
            default: return false
            }
        default: return false
        }
    }

    private mutating func handleAddingKey(_ key: RawTerminal.Key, text: String) -> Bool {
        switch key {
        case .escape: state = state.cancelAddReminder(); return false
        case .enter:
            if !text.isEmpty { addReminder(title: text) }
            return false
        case .backspace: state = state.deleteLastCharacter(); return false
        case let .character(c): state = state.appendCharacter(c); return false
        default: return false
        }
    }

    private mutating func completeSelectedReminder() {
        guard let entry = state.selectedEntry, case let .reminder(id) = entry.type else { return }
        state = state.completeReminder(id: entry.id)
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        reminder.isCompleted = true
        do { try store.save(reminder, commit: true) } catch {
            print("\nFailed to complete reminder: \(error)")
        }
    }

    private mutating func addReminder(title: String) {
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        guard let calendar = store.defaultCalendarForNewReminders() else { return }
        reminder.calendar = calendar
        let dueDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        reminder.dueDateComponents = dueDateComponents
        do { try store.save(reminder, commit: true) } catch {
            print("\nFailed to add reminder: \(error)")
            return
        }
        let id = reminder.calendarItemIdentifier
        let date = Calendar.current.date(from: dueDateComponents) ?? Date()
        let entry = Entry(id: id, date: date, isAllDay: false, title: title, type: .reminder(id: id))
        state = state.addReminder(entry: entry)
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
        case let .reminderAdded(id):
            state = state.undoAddReminder(id: id)
            guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
            do { try store.remove(reminder, commit: true) } catch {
                print("\nFailed to delete reminder: \(error)")
            }
        }
    }
}

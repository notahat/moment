import Foundation

public enum AppMode: Equatable, Sendable {
    case browsing
    case addingReminder(editor: LineEditor)
}

public enum UndoAction: Equatable, Sendable {
    case reminderCompleted(entry: Entry)
    case reminderAdded(entry: Entry)
    case reminderDeleted(snapshot: ReminderSnapshot)
    case eventDeleted(snapshot: EventSnapshot)
}

/// The complete UI state of the app.
///
/// All methods are pure: they return a new `AppState` with no side effects.
/// EventKit work is handled by `Session`, which calls these methods to update state.
///
/// Entries are identified by ID throughout the public interface — index arithmetic
/// is an internal implementation detail.
public struct AppState: Equatable {
    /// All calendar entries to display, sorted by date.
    public var entries: [Entry]

    /// The ID of the currently highlighted entry, or `nil` if the list is empty.
    public var selectedID: String?

    /// Actions that can be undone, in order from oldest to most recent.
    public var undoStack: [UndoAction]

    /// Actions that can be redone, in order from oldest to most recent.
    public var redoStack: [UndoAction]

    /// Whether the user is browsing or composing a new reminder title.
    public var mode: AppMode

    /// The currently highlighted entry, or `nil` if the list is empty.
    public var selectedEntry: Entry? {
        entries.first(where: { $0.id == selectedID })
    }

    /// Creates a new state. If `selectedID` is not found in `entries`, defaults to the first entry.
    public init(entries: [Entry], selectedID: String? = nil, undoStack: [UndoAction] = [], redoStack: [UndoAction] = [], mode: AppMode = .browsing) {
        self.entries = entries
        self.undoStack = undoStack
        self.redoStack = redoStack
        self.mode = mode
        if let id = selectedID, entries.contains(where: { $0.id == id }) {
            self.selectedID = id
        } else {
            self.selectedID = entries.first?.id
        }
    }

    public func moveUp() -> AppState {
        var s = self
        if let i = index(ofEntryWithID: selectedID), i > 0 {
            s.selectedID = entries[i - 1].id
        }
        return s
    }

    public func moveDown() -> AppState {
        var s = self
        if let i = index(ofEntryWithID: selectedID), i < entries.count - 1 {
            s.selectedID = entries[i + 1].id
        }
        return s
    }

    public func completeReminder(id: String) -> AppState {
        guard let entry = entries.first(where: { $0.id == id }) else { return self }
        var s = removeEntry(withID: id)
        s.undoStack.append(.reminderCompleted(entry: entry))
        s.redoStack = []
        return s
    }

    public func deleteReminder(snapshot: ReminderSnapshot) -> AppState {
        var s = removeEntry(withID: snapshot.id)
        s.undoStack.append(.reminderDeleted(snapshot: snapshot))
        s.redoStack = []
        return s
    }

    public func deleteEvent(snapshot: EventSnapshot) -> AppState {
        var s = removeEntry(withID: snapshot.id)
        s.undoStack.append(.eventDeleted(snapshot: snapshot))
        s.redoStack = []
        return s
    }

    public func startAddReminder() -> AppState {
        var s = self
        s.mode = .addingReminder(editor: LineEditor())
        return s
    }

    public func cancelAddReminder() -> AppState {
        var s = self
        s.mode = .browsing
        return s
    }

    public func insertCharacter(_ c: Character) -> AppState {
        transformEditor { $0.insert(c) }
    }

    public func deleteBackward() -> AppState {
        transformEditor { $0.deleteBackward() }
    }

    public func moveCursorLeft() -> AppState {
        transformEditor { $0.moveCursorLeft() }
    }

    public func moveCursorRight() -> AppState {
        transformEditor { $0.moveCursorRight() }
    }

    public func moveCursorToStart() -> AppState {
        transformEditor { $0.moveCursorToStart() }
    }

    public func moveCursorToEnd() -> AppState {
        transformEditor { $0.moveCursorToEnd() }
    }

    public func deleteToEnd() -> AppState {
        transformEditor { $0.deleteToEnd() }
    }

    public func deleteWordBackward() -> AppState {
        transformEditor { $0.deleteWordBackward() }
    }

    private func transformEditor(_ transform: (inout LineEditor) -> Void) -> AppState {
        guard case var .addingReminder(editor) = mode else { return self }
        var s = self
        transform(&editor)
        s.mode = .addingReminder(editor: editor)
        return s
    }

    public func addReminder(entry: Entry) -> AppState {
        guard case .reminder = entry.type else { return self }
        var s = insertEntry(entry)
        s.mode = .browsing
        s.undoStack.append(.reminderAdded(entry: entry))
        s.redoStack = []
        return s
    }

    public func undoCompleteReminder(entry: Entry) -> AppState {
        var s = insertEntry(entry)
        s.redoStack.append(.reminderCompleted(entry: entry))
        s.undoStack.removeLast()
        return s
    }

    public func undoAddReminder(entry: Entry) -> AppState {
        var s = removeEntry(withID: entry.id)
        s.redoStack.append(.reminderAdded(entry: entry))
        s.undoStack.removeLast()
        return s
    }

    public func undoDeleteEvent(snapshot: EventSnapshot) -> AppState {
        var s = insertEntry(snapshot.entry)
        s.redoStack.append(.eventDeleted(snapshot: snapshot))
        s.undoStack.removeLast()
        return s
    }

    public func undoDeleteReminder(snapshot: ReminderSnapshot) -> AppState {
        var s = insertEntry(snapshot.entry)
        s.redoStack.append(.reminderDeleted(snapshot: snapshot))
        s.undoStack.removeLast()
        return s
    }

    public func redoCompleteReminder(entry: Entry) -> AppState {
        var s = removeEntry(withID: entry.id)
        s.undoStack.append(.reminderCompleted(entry: entry))
        s.redoStack.removeLast()
        return s
    }

    public func redoAddReminder(entry: Entry) -> AppState {
        var s = insertEntry(entry)
        s.undoStack.append(.reminderAdded(entry: entry))
        s.redoStack.removeLast()
        return s
    }

    public func redoDeleteEvent(snapshot: EventSnapshot) -> AppState {
        var s = removeEntry(withID: snapshot.id)
        s.undoStack.append(.eventDeleted(snapshot: snapshot))
        s.redoStack.removeLast()
        return s
    }

    public func redoDeleteReminder(snapshot: ReminderSnapshot) -> AppState {
        var s = removeEntry(withID: snapshot.id)
        s.undoStack.append(.reminderDeleted(snapshot: snapshot))
        s.redoStack.removeLast()
        return s
    }

    private func insertEntry(_ entry: Entry) -> AppState {
        var s = self
        let insertAt = s.entries.firstIndex(where: { $0.date > entry.date }) ?? s.entries.count
        s.entries.insert(entry, at: insertAt)
        s.selectedID = entry.id
        return s
    }

    private func removeEntry(withID id: String) -> AppState {
        guard let i = index(ofEntryWithID: id) else { return self }
        var s = self
        s.entries.remove(at: i)
        s.selectedID = s.entries.isEmpty ? nil : s.entries[min(i, s.entries.count - 1)].id
        return s
    }

    private func index(ofEntryWithID id: String?) -> Int? {
        guard let id else { return nil }
        return entries.firstIndex(where: { $0.id == id })
    }
}

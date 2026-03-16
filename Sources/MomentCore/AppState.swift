import Foundation

public enum AppMode: Equatable, Sendable {
    case browsing
    case addingReminder(text: String)
}

public enum UndoAction: Equatable, Sendable {
    case reminderCompleted(entry: Entry)
    case reminderAdded(id: String)
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

    /// Whether the user is browsing or composing a new reminder title.
    public var mode: AppMode

    /// The currently highlighted entry, or `nil` if the list is empty.
    public var selectedEntry: Entry? {
        entries.first(where: { $0.id == selectedID })
    }

    /// Creates a new state. If `selectedID` is not found in `entries`, defaults to the first entry.
    public init(entries: [Entry], selectedID: String? = nil, undoStack: [UndoAction] = [], mode: AppMode = .browsing) {
        self.entries = entries
        self.undoStack = undoStack
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
        guard let i = index(ofEntryWithID: id) else { return self }
        var s = self
        s.undoStack.append(.reminderCompleted(entry: entries[i]))
        s.entries.remove(at: i)
        s.selectedID = s.entries.isEmpty ? nil : s.entries[min(i, s.entries.count - 1)].id
        return s
    }

    public func startAddReminder() -> AppState {
        var s = self
        s.mode = .addingReminder(text: "")
        return s
    }

    public func cancelAddReminder() -> AppState {
        var s = self
        s.mode = .browsing
        return s
    }

    public func appendCharacter(_ c: Character) -> AppState {
        guard case let .addingReminder(text) = mode else { return self }
        var s = self
        s.mode = .addingReminder(text: text + String(c))
        return s
    }

    public func deleteLastCharacter() -> AppState {
        guard case let .addingReminder(text) = mode else { return self }
        var s = self
        s.mode = .addingReminder(text: String(text.dropLast()))
        return s
    }

    public func addReminder(entry: Entry) -> AppState {
        guard case .reminder = entry.type else { return self }
        var s = self
        s.mode = .browsing
        s.undoStack.append(.reminderAdded(id: entry.id))
        let insertAt = s.entries.firstIndex(where: { $0.date > entry.date }) ?? s.entries.count
        s.entries.insert(entry, at: insertAt)
        s.selectedID = entry.id
        return s
    }

    public func undoCompleteReminder(entry: Entry) -> AppState {
        var s = self
        s.undoStack.removeLast()
        let insertAt = s.entries.firstIndex(where: { $0.date > entry.date }) ?? s.entries.count
        s.entries.insert(entry, at: insertAt)
        s.selectedID = entry.id
        return s
    }

    public func undoAddReminder(id: String) -> AppState {
        var s = self
        s.undoStack.removeLast()
        if let i = s.index(ofEntryWithID: id) {
            s.entries.remove(at: i)
            s.selectedID = s.entries.isEmpty ? nil : s.entries[min(i, s.entries.count - 1)].id
        }
        return s
    }

    private func index(ofEntryWithID id: String?) -> Int? {
        guard let id else { return nil }
        return entries.firstIndex(where: { $0.id == id })
    }
}

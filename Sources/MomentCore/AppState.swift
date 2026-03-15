import Foundation

public enum UndoAction: Equatable, Sendable {
    case reminderCompleted(entry: Entry, atIndex: Int)
}

public struct AppState: Equatable {
    public var entries: [Entry]
    public var selectedIndex: Int
    public var undoStack: [UndoAction]

    public init(entries: [Entry], selectedIndex: Int = 0, undoStack: [UndoAction] = []) {
        self.entries = entries
        self.selectedIndex = selectedIndex
        self.undoStack = undoStack
    }
}

public enum Effect: Equatable {
    case completeReminder(id: String)
    case uncompleteReminder(id: String)
    case exit
}

private func applyUndo(state: AppState) -> (AppState, [Effect]) {
    var state = state
    guard let action = state.undoStack.popLast() else {
        return (state, [])
    }
    switch action {
    case let .reminderCompleted(entry, atIndex):
        guard case let .reminder(id) = entry.type else { return (state, []) }
        let insertAt = min(atIndex, state.entries.count)
        state.entries.insert(entry, at: insertAt)
        state.selectedIndex = insertAt
        return (state, [.uncompleteReminder(id: id)])
    }
}

public func handle(key: RawTerminal.Key, state: AppState) -> (AppState, [Effect]) {
    var state = state
    switch key {
    case .up:
        state.selectedIndex = max(0, state.selectedIndex - 1)
        return (state, [])
    case .down:
        state.selectedIndex = min(state.entries.count - 1, state.selectedIndex + 1)
        return (state, [])
    case .enter:
        guard case let .reminder(id) = state.entries[state.selectedIndex].type else {
            return (state, [])
        }
        let completedEntry = state.entries[state.selectedIndex]
        state.undoStack.append(.reminderCompleted(entry: completedEntry, atIndex: state.selectedIndex))
        state.entries.remove(at: state.selectedIndex)
        state.selectedIndex = min(state.selectedIndex, max(0, state.entries.count - 1))
        let effects: [Effect] = state.entries.isEmpty
            ? [.completeReminder(id: id), .exit]
            : [.completeReminder(id: id)]
        return (state, effects)
    case .undo:
        return applyUndo(state: state)
    case .quit:
        return (state, [.exit])
    case .other:
        return (state, [])
    }
}

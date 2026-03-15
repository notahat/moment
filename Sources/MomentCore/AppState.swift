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

    public func handle(key: RawTerminal.Key) -> (AppState, [Effect]) {
        var state = self
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
            return (state, [.completeReminder(id: id)])
        case .undo:
            return state.applyUndo()
        case .quit:
            return (state, [.exit])
        case .other:
            return (state, [])
        }
    }

    private func applyUndo() -> (AppState, [Effect]) {
        var state = self
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
}

public enum Effect: Equatable {
    case completeReminder(id: String)
    case uncompleteReminder(id: String)
    case exit
}

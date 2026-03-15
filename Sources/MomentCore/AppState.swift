import Foundation

public enum UndoAction: Equatable, Sendable {
    case reminderCompleted(entry: Entry)
}

public struct AppState: Equatable {
    public var entries: [Entry]
    public var selectedID: String?
    public var undoStack: [UndoAction]

    public init(entries: [Entry], selectedID: String? = nil, undoStack: [UndoAction] = []) {
        self.entries = entries
        self.undoStack = undoStack
        if let id = selectedID, entries.contains(where: { $0.id == id }) {
            self.selectedID = id
        } else {
            self.selectedID = entries.first?.id
        }
    }

    public func handle(key: RawTerminal.Key) -> (AppState, [Effect]) {
        var state = self
        switch key {
        case .up:
            if let i = entries.firstIndex(where: { $0.id == selectedID }), i > 0 {
                state.selectedID = entries[i - 1].id
            }
            return (state, [])
        case .down:
            if let i = entries.firstIndex(where: { $0.id == selectedID }), i < entries.count - 1 {
                state.selectedID = entries[i + 1].id
            }
            return (state, [])
        case .enter:
            guard let i = entries.firstIndex(where: { $0.id == selectedID }) else { return (state, []) }
            guard case let .reminder(id) = entries[i].type else { return (state, []) }
            state.undoStack.append(.reminderCompleted(entry: entries[i]))
            state.entries.remove(at: i)
            state.selectedID = state.entries.isEmpty ? nil : state.entries[min(i, state.entries.count - 1)].id
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
        guard let action = state.undoStack.popLast() else { return (state, []) }
        switch action {
        case let .reminderCompleted(entry):
            guard case let .reminder(id) = entry.type else { return (state, []) }
            let insertAt = state.entries.firstIndex(where: { $0.date > entry.date }) ?? state.entries.count
            state.entries.insert(entry, at: insertAt)
            state.selectedID = entry.id
            return (state, [.uncompleteReminder(id: id)])
        }
    }
}

public enum Effect: Equatable {
    case completeReminder(id: String)
    case uncompleteReminder(id: String)
    case exit
}

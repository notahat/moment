import Foundation

public enum AppMode: Equatable, Sendable {
    case browsing
    case addingReminder(text: String)
}

public enum UndoAction: Equatable, Sendable {
    case reminderCompleted(entry: Entry)
    case reminderAdded(id: String)
}

public struct AppState: Equatable {
    public var entries: [Entry]
    public var selectedID: String?
    public var undoStack: [UndoAction]
    public var mode: AppMode

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

    public func handle(key: RawTerminal.Key) -> (AppState, [Effect]) {
        switch mode {
        case .browsing:
            handleBrowsingKey(key)
        case let .addingReminder(text):
            handleAddingKey(key, text: text)
        }
    }

    private func handleBrowsingKey(_ key: RawTerminal.Key) -> (AppState, [Effect]) {
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
        case let .character(c):
            switch c {
            case "q", "\u{03}": // q or Ctrl-C
                return (state, [.exit])
            case "u":
                return state.applyUndo()
            case "k":
                if let i = entries.firstIndex(where: { $0.id == selectedID }), i > 0 {
                    state.selectedID = entries[i - 1].id
                }
                return (state, [])
            case "j":
                if let i = entries.firstIndex(where: { $0.id == selectedID }), i < entries.count - 1 {
                    state.selectedID = entries[i + 1].id
                }
                return (state, [])
            case "n":
                state.mode = .addingReminder(text: "")
                return (state, [])
            default:
                return (state, [])
            }
        default:
            return (state, [])
        }
    }

    private func handleAddingKey(_ key: RawTerminal.Key, text: String) -> (AppState, [Effect]) {
        var state = self
        switch key {
        case .escape:
            state.mode = .browsing
            return (state, [])
        case .enter:
            state.mode = .browsing
            return (state, text.isEmpty ? [] : [.addReminder(title: text)])
        case .backspace:
            state.mode = .addingReminder(text: String(text.dropLast()))
            return (state, [])
        case let .character(c):
            state.mode = .addingReminder(text: text + String(c))
            return (state, [])
        default:
            return (state, [])
        }
    }

    /// Applies a follow-up effect produced by EventKit back into the state machine.
    public func applying(followUp: Effect) -> AppState {
        var state = self
        switch followUp {
        case let .reminderAdded(id):
            state.undoStack.append(.reminderAdded(id: id))
        default:
            break
        }
        return state
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
        case let .reminderAdded(id):
            if let i = state.entries.firstIndex(where: { $0.id == id }) {
                state.entries.remove(at: i)
                state.selectedID = state.entries.isEmpty ? nil : state.entries[min(i, state.entries.count - 1)].id
            }
            return (state, [.deleteReminder(id: id)])
        }
    }
}

public enum Effect: Equatable {
    case completeReminder(id: String)
    case uncompleteReminder(id: String)
    case addReminder(title: String)
    case reminderAdded(id: String) // Follow-up from EventKit after addReminder succeeds; no EventKit action.
    case deleteReminder(id: String)
    case exit
}

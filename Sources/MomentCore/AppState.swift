import Foundation

public struct AppState: Equatable {
    public var entries: [Entry]
    public var selectedIndex: Int

    public init(entries: [Entry], selectedIndex: Int = 0) {
        self.entries = entries
        self.selectedIndex = selectedIndex
    }
}

public enum Effect: Equatable {
    case completeReminder(id: String)
    case exit
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
        state.entries.remove(at: state.selectedIndex)
        state.selectedIndex = min(state.selectedIndex, max(0, state.entries.count - 1))
        let effects: [Effect] = state.entries.isEmpty
            ? [.completeReminder(id: id), .exit]
            : [.completeReminder(id: id)]
        return (state, effects)
    case .quit:
        return (state, [.exit])
    case .other:
        return (state, [])
    }
}

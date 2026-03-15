// @preconcurrency suppresses Swift 6 Sendable errors for EventKit types that predate strict concurrency.
@preconcurrency import EventKit
import Foundation
import MomentCore

extension Moment {
    static func runUILoop(entries: [Entry], store: EKEventStore) {
        let terminal = RawTerminal()
        terminal.enterRawMode()
        terminal.hideCursor()
        defer {
            terminal.showCursor()
            terminal.exitRawMode()
        }

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE d MMM yyyy"

        var state = AppState(entries: entries, selectedIndex: 0)

        print(renderAppState(state, dateFormatter: dateFormatter, timeFormatter: timeFormatter), terminator: "")

        while true {
            let key = terminal.readKey()
            let (newState, effects) = state.handle(key: key)
            state = newState
            print(renderAppState(state, dateFormatter: dateFormatter, timeFormatter: timeFormatter), terminator: "")
            for effect in effects {
                handleEffect(effect, store: store)
            }
            if effects.contains(.exit) { break }
        }

        terminal.clearScreen()
    }
}

// @preconcurrency suppresses Swift 6 Sendable errors for EventKit types that predate strict concurrency.
@preconcurrency import EventKit
import Foundation
import MomentCore

private actor RefreshSignal {
    private var pending = false
    func signal() {
        pending = true
    }

    func consume() -> Bool {
        defer { pending = false }; return pending
    }
}

struct UILoop {
    private init() {} // Namespace only — not intended to be instantiated.

    static func run(store: EKEventStore) async {
        let terminal = RawTerminal()
        terminal.enterRawMode()
        terminal.hideCursor()

        let refreshSignal = RefreshSignal()
        let stopObserver = await startObserver(store: store, refreshSignal: refreshSignal)

        defer {
            stopObserver()
            terminal.showCursor()
            terminal.exitRawMode()
        }

        await runLoop(terminal: terminal, store: store, refreshSignal: refreshSignal)
        terminal.clearScreen()
    }

    /// Starts a background thread with a running RunLoop, which EventKit needs to detect
    /// changes from the system. Registers an EKEventStoreChanged observer on that thread,
    /// and returns a closure that stops the thread and removes the observer.
    private static func startObserver(store: EKEventStore, refreshSignal: RefreshSignal) async -> () -> Void {
        await withCheckedContinuation { continuation in
            Thread.detachNewThread {
                let cfRunLoop = CFRunLoopGetCurrent()!
                let port = Port()
                NotificationCenter.default.addObserver(
                    forName: .EKEventStoreChanged, object: store, queue: nil,
                ) { _ in
                    Task { await refreshSignal.signal() }
                }
                RunLoop.current.add(port, forMode: .default)
                continuation.resume(returning: {
                    port.invalidate()
                    CFRunLoopStop(cfRunLoop)
                })
                RunLoop.current.run()
            }
        }
    }

    private static func runLoop(terminal: RawTerminal, store: EKEventStore, refreshSignal: RefreshSignal) async {
        var state = await AppState(entries: fetchCurrentEntries(store: store), selectedIndex: 0)
        render(state)

        while true {
            let (newState, effects) = readInput(from: terminal, state: state)
            state = newState
            render(state)
            if handleEffects(effects, store: store) { break }
            if let refreshedState = await handleRefresh(state: state, store: store, refreshSignal: refreshSignal) {
                state = refreshedState
                render(state)
            }
        }
    }

    private static func readInput(from terminal: RawTerminal, state: AppState) -> (AppState, [Effect]) {
        state.handle(key: terminal.readKey())
    }

    private static func render(_ state: AppState) {
        print(Renderer.renderAppState(state, dateFormatter: dateFormatter, timeFormatter: timeFormatter), terminator: "")
    }

    private static func handleEffects(_ effects: [Effect], store: EKEventStore) -> Bool {
        for effect in effects {
            Effects.handleEffect(effect, store: store)
        }
        return effects.contains(.exit)
    }

    private static func handleRefresh(state: AppState, store: EKEventStore, refreshSignal: RefreshSignal) async -> AppState? {
        guard await refreshSignal.consume() else { return nil }
        let newEntries = await fetchCurrentEntries(store: store)
        return AppState(entries: newEntries, selectedIndex: min(state.selectedIndex, max(0, newEntries.count - 1)))
    }

    private static func fetchCurrentEntries(store: EKEventStore) async -> [Entry] {
        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: now)!
        return await Fetching.fetchEntries(store: store, from: now, to: end)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE d MMM yyyy"
        return f
    }()
}

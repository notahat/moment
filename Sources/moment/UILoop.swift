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

private actor ResizeSignal {
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
        let resizeSignal = ResizeSignal()
        let stopObserver = await startObserver(refreshSignal: refreshSignal)
        let sigwinchSource = makeResizeSource(resizeSignal: resizeSignal)

        defer {
            sigwinchSource.cancel()
            stopObserver()
            terminal.resetCursorStyle()
            terminal.showCursor()
            terminal.exitRawMode()
        }

        await runLoop(terminal: terminal, store: store, refreshSignal: refreshSignal, resizeSignal: resizeSignal)
        terminal.clearScreen()
    }

    private static func makeResizeSource(resizeSignal: ResizeSignal) -> any DispatchSourceSignal {
        signal(SIGWINCH, SIG_IGN) // Suppress default disposition so DispatchSource receives it
        let source = DispatchSource.makeSignalSource(signal: SIGWINCH, queue: .global())
        source.setEventHandler { Task { await resizeSignal.signal() } }
        source.resume()
        return source
    }

    /// Starts a background thread with a running RunLoop, which EventKit needs to detect
    /// changes from the system. Registers an EKEventStoreChanged observer on that thread,
    /// and returns a closure that stops the thread and removes the observer.
    private static func startObserver(refreshSignal: RefreshSignal) async -> () -> Void {
        await withCheckedContinuation { continuation in
            Thread.detachNewThread {
                let cfRunLoop = CFRunLoopGetCurrent()!
                let port = Port()
                NotificationCenter.default.addObserver(
                    forName: .EKEventStoreChanged, object: nil, queue: nil,
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

    private static func runLoop(terminal: RawTerminal, store: EKEventStore, refreshSignal: RefreshSignal, resizeSignal: ResizeSignal) async {
        var session = await Session(store: store, entries: fetchCurrentEntries(store: store))
        render(session.state)

        var shouldExit = false
        while !shouldExit {
            // Handle keypresses, and re-render if necessary.
            let previousState = session.state
            shouldExit = session.handle(key: terminal.readKey())
            if session.state != previousState { render(session.state) }

            // Handle external changes, and re-render if necessary.
            if !shouldExit, await refreshSignal.consume() {
                await session.refresh(entries: fetchCurrentEntries(store: store))
                render(session.state)
            }

            // Handle terminal resize — just re-render to redraw for the new dimensions.
            if !shouldExit, await resizeSignal.consume() {
                render(session.state)
            }
        }
    }

    private static func render(_ state: AppState) {
        print(Renderer.renderAppState(state, dateFormatter: dateFormatter, timeFormatter: timeFormatter), terminator: "")
        fflush(stdout)
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

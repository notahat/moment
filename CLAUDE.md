# moment

A macOS command-line tool that lists calendar events and reminders for the next 7 days.

## Structure

- `Sources/moment/` — `@main` entry point only
- `Sources/MomentCore/` — library with `Entry`, `EntryType`, `Terminal` helpers
- `Tests/MomentCoreTests/` — tests for entry formatting

`MomentCore` is a separate library target so tests can import it (executable targets can't be imported by test targets in SPM).

## Before committing

1. Run `swiftformat .`
2. Run `swift test` and ensure all tests pass

## Code organisation

Swift lacks namespaces. To group related functions, use a struct with a `private init()` to prevent instantiation:

```swift
struct Fetching {
    private init() {} // Namespace only — not intended to be instantiated.

    static func fetchEntries(...) { ... }
    private static func fetchEvents(...) { ... }
}
```

This makes call sites self-documenting (`Fetching.fetchEntries(...)`) and allows private static methods for implementation details.

## Concurrency

Use Swift 6 concurrency (async/await, `Sendable`, actors). Do not downgrade to Swift 5 concurrency mode. `Entry` and `EntryType` are marked `Sendable` to satisfy Swift 6 requirements.

EventKit types predate strict concurrency, so both EventKit imports use `@preconcurrency` to suppress false Sendable errors.

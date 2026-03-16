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

## Architecture

`Session` owns both the `EKEventStore` and `AppState`. When the user takes an action:
- `Session` performs any EventKit work
- `Session` calls a pure transformation method on `AppState` to update state
- `AppState` methods have no side effects

**Prefer optimistic updates**: update `AppState` immediately rather than waiting for an `EKEventStoreChanged` refresh. The refresh will reconcile eventually, but the UI should feel instant.

**Work with IDs, not indexes**: methods on `AppState` take and return entry IDs. Index lookups are an internal implementation detail of `AppState`, not part of its public interface.

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

## Function design

Break functions into meaningful chunks at logical boundaries, not at arbitrary line counts. A good signal that a function needs splitting is when you find yourself writing comments to label what each block does — that's a sign the blocks want to be named functions instead.

Avoid extracting trivial one-liners into helpers unless they're called in multiple places or form part of a coherent set of named operations.

Within a file, order functions so the public entry point comes first, with private helpers below in call-tree order — things further down the call tree go further down the file. This lets the file read top-down from high-level to detail.

## Concurrency

Use Swift 6 concurrency (async/await, `Sendable`, actors). Do not downgrade to Swift 5 concurrency mode. `Entry` and `EntryType` are marked `Sendable` to satisfy Swift 6 requirements.

EventKit types predate strict concurrency, so both EventKit imports use `@preconcurrency` to suppress false Sendable errors.

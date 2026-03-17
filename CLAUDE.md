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

## Documentation

Every type (struct, class, enum, actor) should have a doc comment explaining its responsibility. Focus on the *what and why*, not the *how* — the code itself shows how. A good type-level comment answers: what does this type own or represent, and what is it responsible for doing?

```swift
/// Converts `AppState` into a terminal output string.
///
/// All output is built as a single string (starting with a clear-screen sequence)
/// and written to stdout in one call, avoiding partial-render flicker.
public struct Renderer {
```

Methods only need doc comments when their behaviour is non-obvious from the name — e.g. when there are meaningful edge cases, side effects, or non-obvious parameter semantics worth calling out.

A good comment explains *why* the code is the way it is, not *what* it does — the code already shows what. If a comment just restates the code in prose, delete it.

## Function design

Break functions into meaningful chunks at logical boundaries, not at arbitrary line counts. A good signal that a function needs splitting is when you find yourself writing comments to label what each block does — that's a sign the blocks want to be named functions instead.

Avoid extracting trivial one-liners into helpers unless they're called in multiple places or form part of a coherent set of named operations.

Within a file, order functions so the public entry point comes first, with private helpers below in call-tree order — things further down the call tree go further down the file. This lets the file read top-down from high-level to detail.

Method names should start with a present-tense verb: `removeEntry`, `insertEntry`, `fetchEvents`. Avoid gerunds (`-ing` forms) like `removingEntry` or `insertingEntry`.

## Concurrency

Use Swift 6 concurrency (async/await, `Sendable`, actors). Do not downgrade to Swift 5 concurrency mode. `Entry` and `EntryType` are marked `Sendable` to satisfy Swift 6 requirements.

EventKit types predate strict concurrency, so both EventKit imports use `@preconcurrency` to suppress false Sendable errors. Don't use `nonisolated(unsafe)` or `@unchecked Sendable` as a workaround unless you can justify thread safety manually (as `RawTerminal` does).

## Public API surface

`MomentCore` is a library — be deliberate about what gets marked `public`. A type or method should be public only if it needs to be testable or reusable outside the library. If it only supports internal implementation, keep it `internal`.

## Enums for variant types

When a value can be one of several distinct cases with different associated data, use an enum rather than optional fields or a type hierarchy. All enums that cross actor boundaries must be `Sendable` and `Equatable`. Give associated values explicit labels (`case event(meetingURL: URL?, locationURL: URL?)`) rather than positional unlabelled tuples.

## Styling and escape sequences

All ANSI sequences live in `Styling`. Never inline raw escape codes (`\u{001B}[...]`) elsewhere — use `Styling.applyStyle()` or add a named constant to `Styling`. This keeps terminal output changes localised.

## Error handling

At EventKit boundaries, use `guard let ... else { return }` and fail silently or print a diagnostic — don't crash on missing items. Don't propagate `throws` for recoverable EventKit failures; callers can't do anything useful with them.

## Testing

Use the Swift Testing framework (`@Test`, struct-based suites, `#expect`). Group related tests under `// MARK: -` sections. Extract repeated setup into small `make*` helpers (`makeEntry()`, `makeDate()`) rather than duplicating inline.

Test the public interface of a type, not its internal implementation — if a test needs to reach into private state, that's a signal to expose a better public method instead.

Strip ANSI codes before asserting on rendered strings using a `stripANSI(_:)` helper.

// @preconcurrency suppresses Swift 6 Sendable errors for EventKit types that predate strict concurrency.
@preconcurrency import EventKit
import Foundation
import MomentCore

@main
struct Moment {
    static func main() async {
        await requestAccess()

        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: now)!
        let store = EKEventStore()
        let entries = await fetchEntries(store: store, from: now, to: end)

        if entries.isEmpty {
            print("No events or reminders in the next 7 days.")
            return
        }

        let terminal = RawTerminal()
        terminal.enterRawMode()
        defer { terminal.exitRawMode() }

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE d MMM yyyy"

        var state = AppState(entries: entries, selectedIndex: 0)

        print(render(state: state, dateFormatter: dateFormatter, timeFormatter: timeFormatter), terminator: "")

        loop: while true {
            let key = terminal.readKey()
            let (newState, effects) = handle(key: key, state: state)
            state = newState
            print(render(state: state, dateFormatter: dateFormatter, timeFormatter: timeFormatter), terminator: "")
            for effect in effects {
                switch effect {
                case let .completeReminder(id):
                    complete(id: id, store: store)
                case .exit:
                    break loop
                }
            }
        }

        // Clear screen on exit
        print("\u{001B}[2J\u{001B}[H", terminator: "")
    }

    static func requestAccess() async {
        let store = EKEventStore()
        do {
            try await store.requestFullAccessToEvents()
            try await store.requestFullAccessToReminders()
        } catch {
            print("Error requesting access: \(error)")
            exit(1)
        }
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            print("Calendar access denied. Grant access in System Settings > Privacy & Security > Calendars.")
            exit(1)
        }
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
            print("Reminders access denied. Grant access in System Settings > Privacy & Security > Reminders.")
            exit(1)
        }
    }

    static func fetchEntries(store: EKEventStore, from start: Date, to end: Date) async -> [Entry] {
        let events = fetchEvents(store: store, from: start, to: end)
        let reminders = await fetchReminders(store: store, from: start, to: end)
        let entries = events + reminders
        return entries.sorted { $0.date < $1.date }
    }

    static func fetchEvents(store: EKEventStore, from start: Date, to end: Date) -> [Entry] {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map { Entry(event: $0) }
    }

    static func fetchReminders(store: EKEventStore, from start: Date, to end: Date) async -> [Entry] {
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        let startOfDay = Calendar.current.startOfDay(for: start)
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let entries = (reminders ?? []).compactMap { reminder -> Entry? in
                    let entry = Entry(reminder: reminder, fallbackDate: start)
                    // Include reminders with no due date, and those due within our window
                    if reminder.dueDateComponents == nil {
                        return entry
                    }
                    return entry.date >= startOfDay && entry.date <= end ? entry : nil
                }
                continuation.resume(returning: entries)
            }
        }
    }

    static func complete(id: String, store: EKEventStore) {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        reminder.isCompleted = true
        do { try store.save(reminder, commit: true) } catch {
            print("\nFailed to complete reminder: \(error)")
        }
    }
}

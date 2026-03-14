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
        let entries = await fetchEntries(from: now, to: end)

        if entries.isEmpty {
            print("No events or reminders in the next 7 days.")
        } else {
            printEntries(entries)
        }
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

    static func fetchEntries(from start: Date, to end: Date) async -> [Entry] {
        let store = EKEventStore()
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
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: start, ending: end, calendars: nil)
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: (reminders ?? []).map { Entry(reminder: $0, fallbackDate: start) })
            }
        }
    }

    static func printEntries(_ entries: [Entry]) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE d MMM yyyy"

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none

        let entriesByDay = Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.date) }
        for day in entriesByDay.keys.sorted() {
            print("\n\(colored(dateFormatter.string(from: day), .bold, .blue))")
            for entry in entriesByDay[day]! {
                print(entry.format(timeFormatter: timeFormatter))
            }
        }
    }
}

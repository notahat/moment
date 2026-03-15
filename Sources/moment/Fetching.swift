// @preconcurrency suppresses Swift 6 Sendable errors for EventKit types that predate strict concurrency.
@preconcurrency import EventKit
import Foundation
import MomentCore

extension Moment {
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
}

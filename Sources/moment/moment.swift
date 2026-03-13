@preconcurrency import EventKit
import Foundation

enum Color: String {
    case reset = "\u{001B}[0m"
    case bold = "\u{001B}[1m"
    case dim = "\u{001B}[2m"
    case blue = "\u{001B}[34m"
    case yellow = "\u{001B}[33m"
}

func colored(_ text: String, _ colors: Color...) -> String {
    colors.map(\.rawValue).joined() + text + Color.reset.rawValue
}

struct Entry {
    let date: Date
    let isAllDay: Bool
    let title: String
    let isReminder: Bool

    init(event: EKEvent) {
        date = event.startDate
        isAllDay = event.isAllDay
        title = event.title ?? "(no title)"
        isReminder = false
    }

    init(reminder: EKReminder, fallbackDate: Date) {
        let components = reminder.dueDateComponents
        date = components?.date ?? fallbackDate
        isAllDay = components?.hour == nil
        title = reminder.title ?? "(no title)"
        isReminder = true
    }
}

@main
struct Moment {
    static func main() async {
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

        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: now)!

        let entries = (fetchEvents(store: store, from: now, to: end)
            + (await fetchReminders(store: store, from: now, to: end)))
            .sorted { $0.date < $1.date }

        if entries.isEmpty {
            print("No events or reminders in the next 7 days.")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE d MMM yyyy"

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none

        var currentDay: String?

        for entry in entries {
            let day = dateFormatter.string(from: entry.date)
            if day != currentDay {
                print("\n\(colored(day, .bold, .blue))")
                currentDay = day
            }

            let timeStr = entry.isAllDay ? "All day" : timeFormatter.string(from: entry.date)
            let kindStr = entry.isReminder ? colored(" [reminder]", .yellow) : ""
            print("  \(colored(timeStr.padding(toLength: 8, withPad: " ", startingAt: 0), .dim)) \(entry.title)\(kindStr)")
        }
    }

    static func fetchEvents(store: EKEventStore, from start: Date, to end: Date) -> [Entry] {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map { Entry(event: $0) }
    }

    static func fetchReminders(store: EKEventStore, from start: Date, to end: Date) async -> [Entry] {
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: start, ending: end, calendars: nil)
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let entries = (reminders ?? []).map { Entry(reminder: $0, fallbackDate: start) }
                continuation.resume(returning: entries)
            }
        }
    }
}

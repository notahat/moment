@preconcurrency import EventKit
import Foundation

enum EntryType {
    case event(meetingURL: URL?)
    case reminder
    case birthday(contactURL: URL?)
}

struct Entry {
    let date: Date
    let isAllDay: Bool
    let title: String
    let type: EntryType

    init(event: EKEvent) {
        date = event.startDate
        isAllDay = event.isAllDay
        title = event.title ?? "(no title)"
        type = event.calendar.type == .birthday ? .birthday(contactURL: event.url) : .event(meetingURL: event.url)
    }

    init(reminder: EKReminder, fallbackDate: Date) {
        let components = reminder.dueDateComponents
        date = components?.date ?? fallbackDate
        isAllDay = components?.hour == nil
        title = reminder.title ?? "(no title)"
        type = .reminder
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

        let entriesByDay = Dictionary(grouping: entries) { dateFormatter.string(from: $0.date) }
        let days = entriesByDay.keys.sorted()

        for day in days {
            print("\n\(colored(day, .bold, .blue))")
            for entry in entriesByDay[day]! {
                let timeStr = entry.isAllDay ? "All day" : timeFormatter.string(from: entry.date)
                let titleStr: String
                let suffixStr: String
                switch entry.type {
                case .event(let meetingURL):
                    titleStr = entry.title
                    suffixStr = meetingURL.map { " " + colored(hyperlink("[Join]", url: $0), .blue) } ?? ""
                case .reminder:
                    titleStr = entry.title
                    suffixStr = colored(" [reminder]", .yellow)
                case .birthday(let contactURL):
                    titleStr = contactURL.map { hyperlink(entry.title, url: $0) } ?? entry.title
                    suffixStr = " 🎈"
                }
                print("  \(colored(timeStr.padding(toLength: 8, withPad: " ", startingAt: 0), .dim)) \(titleStr)\(suffixStr)")
            }
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

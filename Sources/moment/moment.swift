import EventKit
import Foundation

@main
struct Moment {
    static func main() async {
        let store = EKEventStore()

        do {
            try await store.requestFullAccessToEvents()
        } catch {
            print("Error requesting calendar access: \(error)")
            return
        }

        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            print("Calendar access denied. Grant access in System Settings > Privacy & Security > Calendars.")
            return
        }

        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 3, to: now)!

        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let events = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }

        if events.isEmpty {
            print("No events in the next 3 days.")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none

        var currentDay: String?

        for event in events {
            let day = dateFormatter.string(from: event.startDate)
            if day != currentDay {
                print("\n\(day)")
                currentDay = day
            }

            if event.isAllDay {
                print("  All day  \(event.title ?? "(no title)")")
            } else {
                let time = timeFormatter.string(from: event.startDate)
                print("  \(time)  \(event.title ?? "(no title)")")
            }
        }
    }
}

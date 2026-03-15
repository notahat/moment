// @preconcurrency suppresses Swift 6 Sendable errors for EventKit types that predate strict concurrency.
@preconcurrency import EventKit
import Foundation

public enum EntryType: Equatable, Sendable {
    case event(meetingURL: URL?, locationURL: URL?)
    case reminder(id: String)
    case birthday(contactURL: URL?)
}

public struct Entry: Equatable, Sendable {
    public let date: Date
    public let isAllDay: Bool
    public let title: String
    public let type: EntryType

    public init(event: EKEvent) {
        self.init(event: event, calendarType: event.calendar.type)
    }

    /// Separated from init(event:) so tests can pass a calendarType directly,
    /// without needing to construct an EKCalendar with a specific type.
    init(event: EKEvent, calendarType: EKCalendarType) {
        date = event.startDate
        isAllDay = event.isAllDay
        title = event.title ?? "(no title)"
        if calendarType == .birthday {
            type = .birthday(contactURL: event.url)
        } else {
            let locationURL = event.location.flatMap {
                var components = URLComponents()
                components.scheme = "maps"
                components.queryItems = [URLQueryItem(name: "q", value: $0)]
                return components.url
            }
            type = .event(meetingURL: event.url, locationURL: locationURL)
        }
    }

    public init(reminder: EKReminder, fallbackDate: Date) {
        let components = reminder.dueDateComponents
        date = components?.date ?? fallbackDate
        isAllDay = components?.hour == nil
        title = reminder.title ?? "(no title)"
        type = .reminder(id: reminder.calendarItemIdentifier)
    }

    public init(date: Date, isAllDay: Bool, title: String, type: EntryType) {
        self.date = date
        self.isAllDay = isAllDay
        self.title = title
        self.type = type
    }
}

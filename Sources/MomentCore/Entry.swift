// @preconcurrency suppresses Swift 6 Sendable errors for EventKit types that predate strict concurrency.
@preconcurrency import EventKit
import Foundation

public enum EntryType {
    case event(meetingURL: URL?)
    case reminder
    case birthday(contactURL: URL?)
}

public struct Entry {
    public let date: Date
    public let isAllDay: Bool
    public let title: String
    public let type: EntryType

    public init(event: EKEvent) {
        date = event.startDate
        isAllDay = event.isAllDay
        title = event.title ?? "(no title)"
        type = event.calendar.type == .birthday ? .birthday(contactURL: event.url) : .event(meetingURL: event.url)
    }

    public init(reminder: EKReminder, fallbackDate: Date) {
        let components = reminder.dueDateComponents
        date = components?.date ?? fallbackDate
        isAllDay = components?.hour == nil
        title = reminder.title ?? "(no title)"
        type = .reminder
    }

    public init(date: Date, isAllDay: Bool, title: String, type: EntryType) {
        self.date = date
        self.isAllDay = isAllDay
        self.title = title
        self.type = type
    }

    public func format(timeFormatter: DateFormatter) -> String {
        let timeStr = isAllDay ? "All day" : timeFormatter.string(from: date)
        let titleStr: String
        let suffixStr: String
        switch type {
        case let .event(meetingURL):
            titleStr = title
            suffixStr = meetingURL.map { " " + colored(hyperlink("[Join]", url: $0), .blue) } ?? ""
        case .reminder:
            titleStr = title
            suffixStr = colored(" [reminder]", .yellow)
        case let .birthday(contactURL):
            titleStr = contactURL.map { hyperlink(title, url: $0) } ?? title
            suffixStr = " 🎈"
        }
        return "  \(colored(timeStr.padding(toLength: 8, withPad: " ", startingAt: 0), .dim)) \(titleStr)\(suffixStr)"
    }
}

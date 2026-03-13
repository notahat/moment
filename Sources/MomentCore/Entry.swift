// @preconcurrency suppresses Swift 6 Sendable errors for EventKit types that predate strict concurrency.
@preconcurrency import EventKit
import Foundation

public enum EntryType: Sendable {
    case event(meetingURL: URL?, locationURL: URL?)
    case reminder
    case birthday(contactURL: URL?)
}

public struct Entry: Sendable {
    public let date: Date
    public let isAllDay: Bool
    public let title: String
    public let type: EntryType

    public init(event: EKEvent) {
        date = event.startDate
        isAllDay = event.isAllDay
        title = event.title ?? "(no title)"
        if event.calendar.type == .birthday {
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
        case let .event(meetingURL, locationURL):
            titleStr = title
            let joinStr = meetingURL.map { " " + colored(hyperlink("[Join]", url: $0), .blue) } ?? ""
            let mapStr = locationURL.map { " " + colored(hyperlink("[Map]", url: $0), .blue) } ?? ""
            suffixStr = joinStr + mapStr
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

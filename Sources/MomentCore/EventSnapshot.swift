import Foundation

/// A full snapshot of an event's data, captured before deletion so it can be faithfully
/// recreated on undo. Unlike `Entry`, which carries only what's needed for display,
/// `EventSnapshot` preserves the complete set of fields that EventKit supports.
public struct EventSnapshot: Equatable, Sendable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let calendarIdentifier: String
    public let location: String?
    public let notes: String?
    public let url: URL?

    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        calendarIdentifier: String,
        location: String?,
        notes: String?,
        url: URL?,
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarIdentifier = calendarIdentifier
        self.location = location
        self.notes = notes
        self.url = url
    }

    /// An `Entry` suitable for inserting into the displayed list.
    public var entry: Entry {
        let locationURL = location.flatMap {
            var components = URLComponents()
            components.scheme = "maps"
            components.queryItems = [URLQueryItem(name: "q", value: $0)]
            return components.url
        }
        return Entry(
            id: id,
            date: startDate,
            isAllDay: isAllDay,
            title: title,
            type: .event(meetingURL: url, locationURL: locationURL),
        )
    }
}

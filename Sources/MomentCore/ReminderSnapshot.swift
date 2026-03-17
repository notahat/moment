import Foundation

/// A full snapshot of a reminder's data, captured before deletion so it can be faithfully
/// recreated on undo. Unlike `Entry`, which carries only what's needed for display,
/// `ReminderSnapshot` preserves the complete set of fields that EventKit supports.
public struct ReminderSnapshot: Equatable, Sendable {
    public let id: String
    public let title: String
    public let date: Date
    public let calendarIdentifier: String
    public let notes: String?
    public let priority: Int
    public let dueDateComponents: DateComponents?
    public let url: URL?

    public init(
        id: String,
        title: String,
        date: Date,
        calendarIdentifier: String,
        notes: String?,
        priority: Int,
        dueDateComponents: DateComponents?,
        url: URL?,
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.calendarIdentifier = calendarIdentifier
        self.notes = notes
        self.priority = priority
        self.dueDateComponents = dueDateComponents
        self.url = url
    }

    /// An `Entry` suitable for inserting into the displayed list.
    public var entry: Entry {
        Entry(id: id, date: date, isAllDay: false, title: title, type: .reminder(id: id))
    }
}

// @preconcurrency suppresses Swift 6 Sendable errors for EventKit types that predate strict concurrency.
@preconcurrency import EventKit
import Foundation
import MomentCore

extension ReminderSnapshot {
    init(reminder: EKReminder, date: Date) {
        self.init(
            id: reminder.calendarItemIdentifier,
            title: reminder.title ?? "",
            date: date,
            calendarIdentifier: reminder.calendar.calendarIdentifier,
            notes: reminder.notes,
            priority: reminder.priority,
            dueDateComponents: reminder.dueDateComponents,
            url: reminder.url,
        )
    }
}

// @preconcurrency suppresses Swift 6 Sendable errors for EventKit types that predate strict concurrency.
@preconcurrency import EventKit
import Foundation
import MomentCore

extension EventSnapshot {
    init(event: EKEvent) {
        self.init(
            id: event.calendarItemIdentifier,
            title: event.title ?? "",
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            calendarIdentifier: event.calendar.calendarIdentifier,
            location: event.location,
            notes: event.notes,
            url: event.url,
        )
    }
}

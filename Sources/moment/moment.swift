// @preconcurrency suppresses Swift 6 Sendable errors for EventKit types that predate strict concurrency.
@preconcurrency import EventKit
import Foundation
import MomentCore

@main
struct Moment {
    static func main() async {
        await requestAccess()

        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: now)!
        let store = EKEventStore()
        let entries = await fetchEntries(store: store, from: now, to: end)

        runUILoop(entries: entries, store: store)
    }
}

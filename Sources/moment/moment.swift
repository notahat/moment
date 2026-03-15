// @preconcurrency suppresses Swift 6 Sendable errors for EventKit types that predate strict concurrency.
@preconcurrency import EventKit
import Foundation
import MomentCore

@main
struct Moment {
    static func main() async {
        await Fetching.requestAccess()

        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: now)!
        let store = EKEventStore()
        let entries = await Fetching.fetchEntries(store: store, from: now, to: end)

        UILoop.run(entries: entries, store: store)
    }
}

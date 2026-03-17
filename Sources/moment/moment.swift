// @preconcurrency suppresses Swift 6 Sendable errors for EventKit types that predate strict concurrency.
@preconcurrency import EventKit
import Foundation
import MomentCore

@main
struct Moment {
    static func main() async {
        let store = EKEventStore()
        await Fetching.requestAccess(store: store)
        await UILoop.run(store: store)
    }
}

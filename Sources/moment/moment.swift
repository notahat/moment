// @preconcurrency suppresses Swift 6 Sendable errors for EventKit types that predate strict concurrency.
@preconcurrency import EventKit
import Foundation
import MomentCore

@main
struct Moment {
    static func main() async {
        await Fetching.requestAccess()

        let store = EKEventStore()

        await UILoop.run(store: store)
    }
}

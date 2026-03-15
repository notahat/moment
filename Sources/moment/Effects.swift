// @preconcurrency suppresses Swift 6 Sendable errors for EventKit types that predate strict concurrency.
@preconcurrency import EventKit
import MomentCore

struct Effects {
    private init() {} // Namespace only — not intended to be instantiated.

    static func handleEffect(_ effect: Effect, store: EKEventStore) {
        switch effect {
        case let .completeReminder(id):
            complete(id: id, store: store)
        case let .uncompleteReminder(id):
            uncomplete(id: id, store: store)
        case .exit:
            break
        }
    }

    private static func complete(id: String, store: EKEventStore) {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        reminder.isCompleted = true
        do { try store.save(reminder, commit: true) } catch {
            print("\nFailed to complete reminder: \(error)")
        }
    }

    private static func uncomplete(id: String, store: EKEventStore) {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        reminder.isCompleted = false
        do { try store.save(reminder, commit: true) } catch {
            print("\nFailed to uncomplete reminder: \(error)")
        }
    }
}

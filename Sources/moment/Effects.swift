// @preconcurrency suppresses Swift 6 Sendable errors for EventKit types that predate strict concurrency.
@preconcurrency import EventKit
import MomentCore

struct Effects {
    private init() {} // Namespace only — not intended to be instantiated.

    /// Handles an effect and returns a follow-up effect for the state machine if applicable.
    static func handleEffect(_ effect: Effect, store: EKEventStore) -> Effect? {
        switch effect {
        case let .completeReminder(id):
            complete(id: id, store: store)
            return nil
        case let .uncompleteReminder(id):
            uncomplete(id: id, store: store)
            return nil
        case let .addReminder(title):
            guard let id = add(title: title, store: store) else { return nil }
            return .reminderAdded(id: id)
        case .reminderAdded:
            return nil // State-machine notification only; no EventKit action.
        case let .deleteReminder(id):
            delete(id: id, store: store)
            return nil
        case .exit:
            return nil
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

    private static func delete(id: String, store: EKEventStore) {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        do { try store.remove(reminder, commit: true) } catch {
            print("\nFailed to delete reminder: \(error)")
        }
    }

    private static func add(title: String, store: EKEventStore) -> String? {
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        guard let calendar = store.defaultCalendarForNewReminders() else { return nil }
        reminder.calendar = calendar
        reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        do { try store.save(reminder, commit: true) } catch {
            print("\nFailed to add reminder: \(error)")
            return nil
        }
        return reminder.calendarItemIdentifier
    }
}

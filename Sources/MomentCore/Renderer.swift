import Foundation

public struct Renderer {
    private init() {} // Namespace only — not intended to be instantiated.

    /// Renders the full app state as a string to be printed to the terminal, including
    /// a grouped list of entries and a key bindings hint line.
    public static func renderAppState(_ state: AppState, dateFormatter: DateFormatter, timeFormatter: DateFormatter) -> String {
        var out = "\u{001B}[2J\u{001B}[H" // clear screen, cursor home
        if state.entries.isEmpty {
            out += "\r\nNo events or reminders in the next 7 days.\r\n"
        } else {
            let entriesByDay = Dictionary(grouping: state.entries) { Calendar.current.startOfDay(for: $0.date) }
            for day in entriesByDay.keys.sorted() {
                out += "\r\n\(Styling.applyStyle(dateFormatter.string(from: day), .bold, .blue))\r\n"
                for entry in entriesByDay[day]! {
                    out += renderEntry(entry, timeFormatter: timeFormatter, isSelected: entry.id == state.selectedID) + "\r\n"
                }
            }
        }
        out += renderFooter(state.mode)
        return out
    }

    private static func renderFooter(_ mode: AppMode) -> String {
        switch mode {
        case .browsing:
            "\r\n\(Styling.applyStyle("↑/↓/j/k navigate   Enter complete   u undo   n new   q quit", .dim))\r\n"
        case let .addingReminder(text):
            "\r\nNew reminder: \(text)|\r\n\(Styling.applyStyle("Enter confirm   Esc cancel", .dim))\r\n"
        }
    }

    /// Renders a single entry as a terminal line, including time, title, and type-specific
    /// suffixes such as join/map links or a reminder tag.
    public static func renderEntry(_ entry: Entry, timeFormatter: DateFormatter, isSelected: Bool = false) -> String {
        let prefix = isSelected ? "> " : "  "
        let timeStr = entry.isAllDay ? "All day" : timeFormatter.string(from: entry.date)
        let titleStr: String
        let suffixStr: String
        switch entry.type {
        case let .event(meetingURL, locationURL):
            titleStr = entry.title
            let joinStr = meetingURL.map { " " + Styling.applyStyle(Styling.applyHyperlink("[Join]", url: $0), .blue) } ?? ""
            let mapStr = locationURL.map { " " + Styling.applyStyle(Styling.applyHyperlink("[Map]", url: $0), .blue) } ?? ""
            suffixStr = joinStr + mapStr
        case .reminder:
            titleStr = entry.title
            suffixStr = Styling.applyStyle(" [reminder]", .yellow)
        case let .birthday(contactURL):
            titleStr = contactURL.map { Styling.applyHyperlink(entry.title, url: $0) } ?? entry.title
            suffixStr = " 🎈"
        }
        return "\(prefix)\(Styling.applyStyle(timeStr.padding(toLength: 8, withPad: " ", startingAt: 0), .dim)) \(titleStr)\(suffixStr)"
    }
}

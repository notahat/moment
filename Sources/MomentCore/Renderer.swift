import Foundation

/// Converts `AppState` into a terminal output string.
///
/// All output is built as a single string (starting with a clear-screen sequence)
/// and written to stdout in one call, avoiding partial-render flicker.
public struct Renderer {
    private init() {} // Namespace only — not intended to be instantiated.

    /// Renders the full app state as a string to be printed to the terminal, including
    /// a grouped list of entries and a key bindings hint line.
    public static func renderAppState(_ state: AppState, dateFormatter: DateFormatter, timeFormatter: DateFormatter) -> String {
        var out = RawTerminal.clearScreenSequence

        if state.entries.isEmpty {
            out += "\r\nNo events or reminders in the next 7 days.\r\n"
        } else {
            let entriesByDay = Dictionary(grouping: state.entries) { Calendar.current.startOfDay(for: $0.date) }
            for day in entriesByDay.keys.sorted() {
                out += "\r\n\(Styling.applyStyle(dateFormatter.string(from: day), .bold, .blue))\r\n"
                for entry in entriesByDay[day, default: []] {
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
            let hints = Styling.applyStyle("↑/↓/j/k navigate   Enter complete   u undo   r redo   n new   q quit", .dim)
            return "\r\n\(hints)\r\n\(RawTerminal.resetCursorStyleSequence)\(RawTerminal.hideCursorSequence)"

        case let .addingReminder(editor):
            let hints = Styling.applyStyle("Enter confirm   Esc cancel   ←/→ move   ^A/^E line start/end   ^K delete to end   ^W delete word", .dim)
            // DECSC is embedded in the input text at the cursor position; DECRC at the end
            // restores the terminal cursor there — no row counting needed.
            let showCursor = RawTerminal.setCursorStyleBarSequence
                + RawTerminal.showCursorSequence
                + RawTerminal.restoreCursorSequence
            return "\r\nNew reminder: \(editor.textWithSaveCursor())\r\n\(hints)\r\n\(showCursor)"
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

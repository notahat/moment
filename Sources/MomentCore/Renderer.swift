import Foundation

public func render(state: AppState, dateFormatter: DateFormatter, timeFormatter: DateFormatter) -> String {
    var out = "\u{001B}[2J\u{001B}[H" // clear screen, cursor home
    let entriesByDay = Dictionary(grouping: state.entries) { Calendar.current.startOfDay(for: $0.date) }
    var i = 0
    for day in entriesByDay.keys.sorted() {
        out += "\r\n\(colored(dateFormatter.string(from: day), .bold, .blue))\r\n"
        for entry in entriesByDay[day]! {
            out += entry.format(timeFormatter: timeFormatter, isSelected: i == state.selectedIndex) + "\r\n"
            i += 1
        }
    }
    out += "\r\n\(colored("↑/↓/j/k navigate   Enter complete reminder   q quit", .dim))\r\n"
    return out
}

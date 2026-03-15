import Foundation

public enum Color: String {
    case reset = "\u{001B}[0m"
    case bold = "\u{001B}[1m"
    case dim = "\u{001B}[2m"
    case blue = "\u{001B}[34m"
    case yellow = "\u{001B}[33m"
}

/// Wraps text in ANSI escape codes for the given styles, resetting to default at the end.
public func applyStyle(_ text: String, _ colors: Color...) -> String {
    colors.map(\.rawValue).joined() + text + Color.reset.rawValue
}

/// Wraps text in an OSC 8 terminal hyperlink escape sequence for the given URL.
public func applyHyperlink(_ text: String, url: URL) -> String {
    "\u{001B}]8;;\(url.absoluteString)\u{001B}\\\(text)\u{001B}]8;;\u{001B}\\"
}

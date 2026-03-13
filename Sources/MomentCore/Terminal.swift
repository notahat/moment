import Foundation

public enum Color: String {
    case reset = "\u{001B}[0m"
    case bold = "\u{001B}[1m"
    case dim = "\u{001B}[2m"
    case blue = "\u{001B}[34m"
    case yellow = "\u{001B}[33m"
}

public func colored(_ text: String, _ colors: Color...) -> String {
    colors.map(\.rawValue).joined() + text + Color.reset.rawValue
}

public func hyperlink(_ text: String, url: URL) -> String {
    "\u{001B}]8;;\(url.absoluteString)\u{001B}\\\(text)\u{001B}]8;;\u{001B}\\"
}

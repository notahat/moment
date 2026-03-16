/// Manages the text and cursor position for a single-line text input field.
///
/// `cursor` is a character offset into `text` (0 = before first character,
/// `text.count` = after last character). All mutations keep `cursor` in bounds.
public struct LineEditor: Equatable, Sendable {
    public var text: String = ""
    public var cursor: Int = 0

    public init() {}

    /// Initialises with `text`, cursor positioned at the end.
    public init(text: String) {
        self.text = text
        cursor = text.count
    }

    /// Inserts a character at the cursor position and advances the cursor.
    public mutating func insert(_ c: Character) {
        let i = text.index(text.startIndex, offsetBy: cursor)
        text.insert(c, at: i)
        cursor += 1
    }

    /// Deletes the character immediately before the cursor.
    public mutating func deleteBackward() {
        guard cursor > 0 else { return }
        let end = text.index(text.startIndex, offsetBy: cursor)
        let start = text.index(before: end)
        text.remove(at: start)
        cursor -= 1
    }

    /// Deletes all characters from the cursor to the end of the line.
    public mutating func deleteToEnd() {
        let i = text.index(text.startIndex, offsetBy: cursor)
        text = String(text[..<i])
    }

    /// Deletes from the cursor back through any preceding spaces and then the word before them.
    public mutating func deleteWordBackward() {
        guard cursor > 0 else { return }
        var i = cursor
        while i > 0, text[text.index(text.startIndex, offsetBy: i - 1)] == " " {
            i -= 1
        }
        while i > 0, text[text.index(text.startIndex, offsetBy: i - 1)] != " " {
            i -= 1
        }
        let start = text.index(text.startIndex, offsetBy: i)
        let end = text.index(text.startIndex, offsetBy: cursor)
        text.removeSubrange(start ..< end)
        cursor = i
    }

    public mutating func moveCursorLeft() {
        if cursor > 0 { cursor -= 1 }
    }

    public mutating func moveCursorRight() {
        if cursor < text.count { cursor += 1 }
    }

    public mutating func moveCursorToStart() {
        cursor = 0
    }

    public mutating func moveCursorToEnd() {
        cursor = text.count
    }

    /// Returns the text with `RawTerminal.saveCursorSequence` embedded at the cursor position,
    /// for use in rendering the input line with the terminal cursor correctly placed.
    public func textWithSaveCursor() -> String {
        let before = String(text.prefix(cursor))
        let after = String(text.suffix(text.count - cursor))
        return "\(before)\(RawTerminal.saveCursorSequence)\(after)"
    }
}

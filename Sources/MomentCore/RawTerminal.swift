import Darwin
import Foundation

private nonisolated(unsafe) var savedTermios = termios()

private enum ControlByte {
    static let etx: UInt8 = 0x03 // Ctrl-C
    static let ctrlA: UInt8 = 0x01 // Ctrl-A (line start)
    static let ctrlE: UInt8 = 0x05 // Ctrl-E (line end)
    static let ctrlK: UInt8 = 0x0B // Ctrl-K (delete to end)
    static let ctrlW: UInt8 = 0x17 // Ctrl-W (delete word backward)
    static let lf: UInt8 = 0x0A // Line feed
    static let cr: UInt8 = 0x0D // Carriage return
    static let esc: UInt8 = 0x1B // Escape
    static let csi = UInt8(ascii: "[") // CSI introducer — follows ESC in arrow key sequences
}

public final class RawTerminal: @unchecked Sendable {
    private var originalTermios = termios()

    public enum Key: Equatable {
        case up, down, left, right
        case enter, escape, backspace
        case lineStart // Ctrl-A
        case lineEnd // Ctrl-E
        case deleteToEnd // Ctrl-K
        case deleteWordBackward // Ctrl-W
        case character(Character)
        case other
    }

    public init() {}

    public func enterRawMode() {
        tcgetattr(STDIN_FILENO, &originalTermios)
        savedTermios = originalTermios
        var raw = originalTermios
        cfmakeraw(&raw)
        withUnsafeMutableBytes(of: &raw.c_cc) { ptr in
            ptr[Int(VMIN)] = 0 // Return immediately once VTIME elapses, even with no input
            ptr[Int(VTIME)] = 1 // 100ms timeout
        }
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        atexit { tcsetattr(STDIN_FILENO, TCSAFLUSH, &savedTermios) }
    }

    public func exitRawMode() {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
    }

    // MARK: - Escape sequences (strings for embedding in rendered output)

    public static let clearScreenSequence = "\u{001B}[2J\u{001B}[H"
    public static let hideCursorSequence = "\u{001B}[?25l"
    public static let showCursorSequence = "\u{001B}[?25h"
    /// Saves the current cursor position (VT100 DECSC — universally supported).
    public static let saveCursorSequence = "\u{001B}7"
    /// Restores the previously saved cursor position (VT100 DECRC — universally supported).
    public static let restoreCursorSequence = "\u{001B}8"
    /// Sets the cursor to a blinking bar / I-beam (DECSCUSR style 5).
    public static let setCursorStyleBarSequence = "\u{001B}[5 q"
    /// Resets the cursor to the terminal's default style (DECSCUSR style 0).
    public static let resetCursorStyleSequence = "\u{001B}[0 q"

    // MARK: - Direct terminal control

    public func hideCursor() {
        print(RawTerminal.hideCursorSequence, terminator: "")
    }

    public func showCursor() {
        print(RawTerminal.showCursorSequence, terminator: "")
    }

    public func resetCursorStyle() {
        print(RawTerminal.resetCursorStyleSequence, terminator: "")
    }

    public func clearScreen() {
        print(RawTerminal.clearScreenSequence, terminator: "")
    }

    /// Reads the next key from stdin, blocking for up to 100ms.
    /// Returns `.other` if no key is received within the timeout.
    public func readKey() -> Key {
        var buf = [UInt8](repeating: 0, count: 3)
        let n = read(STDIN_FILENO, &buf, 3)
        guard n > 0 else { return .other }
        return RawTerminal.interpretKey(buf, count: n)
    }

    /// Interprets raw bytes read from stdin as a key event. Exposed as a static method for testing.
    static func interpretKey(_ buf: [UInt8], count n: Int) -> Key {
        if n >= 3, buf[0] == ControlByte.esc, buf[1] == ControlByte.csi {
            switch buf[2] {
            case UInt8(ascii: "A"): return .up
            case UInt8(ascii: "B"): return .down
            case UInt8(ascii: "C"): return .right
            case UInt8(ascii: "D"): return .left
            default: return .other
            }
        }

        if n == 1 {
            switch buf[0] {
            case ControlByte.ctrlA: return .lineStart
            case ControlByte.etx: return .character("\u{03}") // Ctrl-C, signal processing is disabled in raw mode
            case ControlByte.ctrlE: return .lineEnd
            case ControlByte.ctrlK: return .deleteToEnd
            case ControlByte.lf, ControlByte.cr: return .enter
            case ControlByte.esc: return .escape
            case ControlByte.ctrlW: return .deleteWordBackward
            case 0x7F: return .backspace
            case 0x20 ... 0x7E: return .character(Character(UnicodeScalar(buf[0])))
            default: return .other
            }
        }

        return .other
    }
}

import Darwin
import Foundation

private nonisolated(unsafe) var savedTermios = termios()

private enum ControlByte {
    static let etx: UInt8 = 0x03 // Ctrl-C
    static let lf: UInt8 = 0x0A // Line feed
    static let cr: UInt8 = 0x0D // Carriage return
    static let esc: UInt8 = 0x1B // Escape
    static let csi = UInt8(ascii: "[") // CSI introducer — follows ESC in arrow key sequences
}

/// Pure function, exposed for testing.
func interpretKey(_ buf: [UInt8], count n: Int) -> RawTerminal.Key {
    if n >= 3, buf[0] == ControlByte.esc, buf[1] == ControlByte.csi {
        switch buf[2] {
        case UInt8(ascii: "A"): return .up
        case UInt8(ascii: "B"): return .down
        default: return .other
        }
    }

    if n == 1 {
        switch buf[0] {
        case ControlByte.etx: return .quit // Ctrl-C, signal processing is disabled in raw mode
        case ControlByte.cr, ControlByte.lf: return .enter
        case UInt8(ascii: "q"): return .quit
        case UInt8(ascii: "u"): return .undo
        case UInt8(ascii: "k"): return .up
        case UInt8(ascii: "j"): return .down
        default: return .other
        }
    }

    return .other
}

public final class RawTerminal: @unchecked Sendable {
    private var originalTermios = termios()

    public enum Key: Equatable { case up, down, enter, quit, undo, other }

    public init() {}

    public func enterRawMode() {
        tcgetattr(STDIN_FILENO, &originalTermios)
        savedTermios = originalTermios
        var raw = originalTermios
        cfmakeraw(&raw)
        withUnsafeMutableBytes(of: &raw.c_cc) { ptr in
            ptr[Int(VMIN)] = 1
            ptr[Int(VTIME)] = 1 // 100ms timeout for escape sequences
        }
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        atexit { tcsetattr(STDIN_FILENO, TCSAFLUSH, &savedTermios) }
    }

    public func exitRawMode() {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
    }

    public func hideCursor() {
        print("\u{001B}[?25l", terminator: "")
    }

    public func showCursor() {
        print("\u{001B}[?25h", terminator: "")
    }

    public func clearScreen() {
        print("\u{001B}[2J\u{001B}[H", terminator: "")
    }

    public func readKey() -> Key {
        var buf = [UInt8](repeating: 0, count: 3)
        let n = read(STDIN_FILENO, &buf, 3)
        guard n > 0 else { return .other }
        return interpretKey(buf, count: n)
    }
}

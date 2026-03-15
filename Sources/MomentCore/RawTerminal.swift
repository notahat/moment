import Darwin
import Foundation

private nonisolated(unsafe) var savedTermios = termios()

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

    public func readKey() -> Key {
        var buf = [UInt8](repeating: 0, count: 3)
        let n = read(STDIN_FILENO, &buf, 3)
        guard n > 0 else { return .other }
        if n >= 3, buf[0] == 27, buf[1] == 91 {
            return buf[2] == 65 ? .up : buf[2] == 66 ? .down : .other
        }
        if n == 1 {
            switch buf[0] {
            case 3: return .quit // Ctrl-C (ETX) — signal processing disabled in raw mode
            case 13, 10: return .enter
            case UInt8(ascii: "q"): return .quit
            case UInt8(ascii: "u"): return .undo
            case UInt8(ascii: "k"): return .up
            case UInt8(ascii: "j"): return .down
            default: return .other
            }
        }
        return .other
    }
}

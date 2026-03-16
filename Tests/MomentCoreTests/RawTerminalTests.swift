@testable import MomentCore
import Testing

struct RawTerminalTests {
    @Test func upArrowKey() {
        #expect(RawTerminal.interpretKey([0x1B, UInt8(ascii: "["), UInt8(ascii: "A")], count: 3) == .up)
    }

    @Test func downArrowKey() {
        #expect(RawTerminal.interpretKey([0x1B, UInt8(ascii: "["), UInt8(ascii: "B")], count: 3) == .down)
    }

    @Test func enterKeyCarriageReturn() {
        #expect(RawTerminal.interpretKey([0x0D], count: 1) == .enter)
    }

    @Test func enterKeyLineFeed() {
        #expect(RawTerminal.interpretKey([0x0A], count: 1) == .enter)
    }

    @Test func ctrlCIsCharacter() {
        #expect(RawTerminal.interpretKey([0x03], count: 1) == .character("\u{03}"))
    }

    @Test func qIsCharacter() {
        #expect(RawTerminal.interpretKey([UInt8(ascii: "q")], count: 1) == .character("q"))
    }

    @Test func uIsCharacter() {
        #expect(RawTerminal.interpretKey([UInt8(ascii: "u")], count: 1) == .character("u"))
    }

    @Test func kIsCharacter() {
        #expect(RawTerminal.interpretKey([UInt8(ascii: "k")], count: 1) == .character("k"))
    }

    @Test func jIsCharacter() {
        #expect(RawTerminal.interpretKey([UInt8(ascii: "j")], count: 1) == .character("j"))
    }

    @Test func escapeKey() {
        #expect(RawTerminal.interpretKey([0x1B], count: 1) == .escape)
    }

    @Test func backspaceKey() {
        #expect(RawTerminal.interpretKey([0x7F], count: 1) == .backspace)
    }

    @Test func nIsCharacter() {
        #expect(RawTerminal.interpretKey([UInt8(ascii: "n")], count: 1) == .character("n"))
    }

    @Test func printableCharacterIsCharacter() {
        #expect(RawTerminal.interpretKey([UInt8(ascii: "x")], count: 1) == .character("x"))
    }

    @Test func unknownEscapeSequenceIsOther() {
        #expect(RawTerminal.interpretKey([0x1B, UInt8(ascii: "["), UInt8(ascii: "Z")], count: 3) == .other)
    }
}

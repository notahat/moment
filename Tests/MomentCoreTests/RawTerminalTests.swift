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

    @Test func ctrlCQuits() {
        #expect(RawTerminal.interpretKey([0x03], count: 1) == .quit)
    }

    @Test func qQuits() {
        #expect(RawTerminal.interpretKey([UInt8(ascii: "q")], count: 1) == .quit)
    }

    @Test func uUndoes() {
        #expect(RawTerminal.interpretKey([UInt8(ascii: "u")], count: 1) == .undo)
    }

    @Test func kMovesUp() {
        #expect(RawTerminal.interpretKey([UInt8(ascii: "k")], count: 1) == .up)
    }

    @Test func jMovesDown() {
        #expect(RawTerminal.interpretKey([UInt8(ascii: "j")], count: 1) == .down)
    }

    @Test func unknownByteIsOther() {
        #expect(RawTerminal.interpretKey([UInt8(ascii: "x")], count: 1) == .other)
    }

    @Test func unknownEscapeSequenceIsOther() {
        #expect(RawTerminal.interpretKey([0x1B, UInt8(ascii: "["), UInt8(ascii: "Z")], count: 3) == .other)
    }
}

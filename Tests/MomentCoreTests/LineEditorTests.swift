import MomentCore
import Testing

struct LineEditorTests {
    @Test func insertAtEnd() {
        var editor = LineEditor()
        editor.insert("a")
        editor.insert("b")
        #expect(editor.text == "ab")
        #expect(editor.cursor == 2)
    }

    @Test func insertAtCursor() {
        var editor = LineEditor()
        editor.insert("a")
        editor.insert("c")
        editor.moveCursorLeft()
        editor.insert("b")
        #expect(editor.text == "abc")
        #expect(editor.cursor == 2)
    }

    @Test func deleteBackwardAtEnd() {
        var editor = LineEditor()
        editor.insert("a")
        editor.insert("b")
        editor.deleteBackward()
        #expect(editor.text == "a")
        #expect(editor.cursor == 1)
    }

    @Test func deleteBackwardAtCursor() {
        var editor = LineEditor()
        editor.insert("a")
        editor.insert("b")
        editor.moveCursorLeft()
        editor.deleteBackward()
        #expect(editor.text == "b")
        #expect(editor.cursor == 0)
    }

    @Test func deleteBackwardAtStart() {
        var editor = LineEditor()
        editor.deleteBackward()
        #expect(editor.text == "")
        #expect(editor.cursor == 0)
    }

    @Test func deleteToEnd() {
        var editor = LineEditor()
        for c in "hello world" {
            editor.insert(c)
        }
        editor.moveCursorToStart()
        editor.moveCursorRight() // cursor after "h"
        editor.moveCursorRight()
        editor.moveCursorRight()
        editor.deleteToEnd()
        #expect(editor.text == "hel")
        #expect(editor.cursor == 3)
    }

    @Test func deleteWordBackwardSimple() {
        var editor = LineEditor()
        for c in "hello world" {
            editor.insert(c)
        }
        editor.deleteWordBackward()
        #expect(editor.text == "hello ")
        #expect(editor.cursor == 6)
    }

    @Test func deleteWordBackwardSkipsTrailingSpaces() {
        var editor = LineEditor()
        for c in "hello world  " {
            editor.insert(c)
        }
        editor.deleteWordBackward()
        #expect(editor.text == "hello ")
        #expect(editor.cursor == 6)
    }

    @Test func deleteWordBackwardAtStart() {
        var editor = LineEditor()
        for c in "hello" {
            editor.insert(c)
        }
        editor.moveCursorToStart()
        editor.deleteWordBackward()
        #expect(editor.text == "hello")
        #expect(editor.cursor == 0)
    }

    @Test func moveCursorLeftClampsAtStart() {
        var editor = LineEditor()
        editor.moveCursorLeft()
        #expect(editor.cursor == 0)
    }

    @Test func moveCursorRightClampsAtEnd() {
        var editor = LineEditor()
        editor.insert("a")
        editor.moveCursorRight()
        editor.moveCursorRight()
        #expect(editor.cursor == 1)
    }

    @Test func moveCursorToStartAndEnd() {
        var editor = LineEditor()
        for c in "hello" {
            editor.insert(c)
        }
        editor.moveCursorToStart()
        #expect(editor.cursor == 0)
        editor.moveCursorToEnd()
        #expect(editor.cursor == 5)
    }
}

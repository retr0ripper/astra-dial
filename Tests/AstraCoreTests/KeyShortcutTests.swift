import Foundation
import Testing
@testable import AstraCore

@Suite struct KeyShortcutTests {
    @Test func displayListsModifiersInMacOrder() {
        let shortcut = KeyShortcut(keyCode: 0x28, modifiers: [.command, .shift, .option, .control], keyLabel: "k")
        #expect(shortcut.display == "⌃⌥⇧⌘K")
    }

    @Test func displayWithoutModifiersIsJustTheKey() {
        #expect(KeyShortcut(keyCode: 0x7C, modifiers: [], keyLabel: "→").display == "→")
    }

    @Test func roundTripsThroughJSON() throws {
        let shortcut = KeyShortcut(keyCode: 0x21, modifiers: [.command, .shift], keyLabel: "[")
        let data = try JSONEncoder().encode(shortcut)
        #expect(try JSONDecoder().decode(KeyShortcut.self, from: data) == shortcut)
    }

    @Test func labelsNamedKeysByKeyCode() {
        #expect(KeyShortcut.label(forKeyCode: 0x31, characters: " ") == "Space")
        #expect(KeyShortcut.label(forKeyCode: 0x7B, characters: "\u{F702}") == "←")
        #expect(KeyShortcut.label(forKeyCode: 0x24, characters: "\r") == "↩")
        #expect(KeyShortcut.label(forKeyCode: 0x7A, characters: "\u{F704}") == "F1")
    }

    @Test func labelsOtherKeysByCharacter() {
        #expect(KeyShortcut.label(forKeyCode: 0x21, characters: "[") == "[")
        #expect(KeyShortcut.label(forKeyCode: 0x00, characters: "a") == "A")
        #expect(KeyShortcut.label(forKeyCode: 0x00, characters: nil) == "Key 0")
    }

    @Test func modifierOnlyKeysAreNotRecordable() {
        #expect(!KeyShortcut.isRecordable(keyCode: 0x37)) // ⌘
        #expect(!KeyShortcut.isRecordable(keyCode: 0x38)) // ⇧
        #expect(KeyShortcut.isRecordable(keyCode: 0x00))
    }
}

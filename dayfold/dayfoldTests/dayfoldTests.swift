import Testing
@testable import dayfold

struct dayfoldTests {

    @Test func editorAreaDoesNotReserveSeparateToolbarHeight() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("dayfold/Views/Entry/EntryEditorView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(!source.contains("Spacer().frame(height: 56)"))
    }

}

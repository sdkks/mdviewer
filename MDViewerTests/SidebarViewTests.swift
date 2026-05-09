import XCTest
@testable import MDViewer

final class SidebarViewTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    // MARK: - File enumeration filters by extension case-insensitively

    func testSiblings_filtersByMarkdownExtension() throws {
        try createFiles(["readme.md", "notes.markdown", "draft.mdown", "memo.mkd", "image.png", "script.js"])
        let state = DocumentState()
        let urls = state.sibling(of: tempDir.appendingPathComponent("readme.md"))
        let names = urls.map { $0.lastPathComponent }.sorted()
        XCTAssertEqual(names, ["draft.mdown", "memo.mkd", "notes.markdown", "readme.md"])
    }

    func testSiblings_caseInsensitiveExtensions() throws {
        try createFiles(["upper.MD", "mixed.Md", "lower.md"])
        let state = DocumentState()
        let urls = state.sibling(of: tempDir.appendingPathComponent("lower.md"))
        let names = urls.map { $0.lastPathComponent }.sorted()
        XCTAssertEqual(names, ["lower.md", "mixed.Md", "upper.MD"])
    }

    // MARK: - Hidden files are excluded

    func testSiblings_hiddenFilesExcluded() throws {
        try createFiles(["visible.md", ".hidden.md"])
        let state = DocumentState()
        let urls = state.sibling(of: tempDir.appendingPathComponent("visible.md"))
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first?.lastPathComponent, "visible.md")
    }

    // MARK: - Alphabetical sort order ascending by lastPathComponent

    func testSiblings_alphabeticalSortAscending() throws {
        try createFiles(["zebra.md", "alpha.md", "mango.md"])
        let state = DocumentState()
        state.sortOrder = .alphabetical
        let urls = state.sibling(of: tempDir.appendingPathComponent("alpha.md"))
        XCTAssertEqual(urls.map { $0.lastPathComponent }, ["alpha.md", "mango.md", "zebra.md"])
    }

    // MARK: - Date-modified sort order descending with distantPast fallback

    func testSiblings_dateModifiedSortDescending() throws {
        let file1 = tempDir.appendingPathComponent("older.md")
        let file2 = tempDir.appendingPathComponent("newer.md")
        let file3 = tempDir.appendingPathComponent("oldest.md")
        try "content".write(to: file1, atomically: true, encoding: .utf8)
        try "content".write(to: file2, atomically: true, encoding: .utf8)
        try "content".write(to: file3, atomically: true, encoding: .utf8)

        let attrs1: [FileAttributeKey: Any] = [.modificationDate: Date(timeIntervalSince1970: 1000)]
        let attrs2: [FileAttributeKey: Any] = [.modificationDate: Date(timeIntervalSince1970: 3000)]
        let attrs3: [FileAttributeKey: Any] = [.modificationDate: Date(timeIntervalSince1970: 500)]
        try FileManager.default.setAttributes(attrs1, ofItemAtPath: file1.path)
        try FileManager.default.setAttributes(attrs2, ofItemAtPath: file2.path)
        try FileManager.default.setAttributes(attrs3, ofItemAtPath: file3.path)

        let state = DocumentState()
        state.sortOrder = .dateModified
        let urls = state.sibling(of: tempDir.appendingPathComponent("older.md"))
        XCTAssertEqual(urls.map { $0.lastPathComponent }, ["newer.md", "older.md", "oldest.md"])
    }

    func testSiblings_dateModifiedFallbackToDistantPast() throws {
        let file1 = tempDir.appendingPathComponent("with-date.md")
        let file2 = tempDir.appendingPathComponent("distant-past.md")
        try "content".write(to: file1, atomically: true, encoding: .utf8)
        try "content".write(to: file2, atomically: true, encoding: .utf8)

        let recent = Date(timeIntervalSince1970: 2000)
        try FileManager.default.setAttributes([.modificationDate: recent], ofItemAtPath: file1.path)
        try FileManager.default.setAttributes([.modificationDate: Date.distantPast], ofItemAtPath: file2.path)

        let state = DocumentState()
        state.sortOrder = .dateModified
        let urls = state.sibling(of: tempDir.appendingPathComponent("with-date.md"))
        // Recent date should come before .distantPast in descending order
        XCTAssertEqual(urls.map { $0.lastPathComponent }, ["with-date.md", "distant-past.md"])
    }

    // MARK: - Empty-state behavior

    func testNavigate_withNoCurrentURL_isNoop() {
        let state = DocumentState()
        XCTAssertNil(state.currentURL)
        state.navigatePrevious() // should not crash
        state.navigateNext()     // should not crash
    }

    func testSiblings_noMarkdownFiles_returnsEmpty() throws {
        try createFiles(["image.png", "script.js"])
        let state = DocumentState()
        let urls = state.sibling(of: tempDir.appendingPathComponent("image.png"))
        XCTAssertTrue(urls.isEmpty)
    }

    // MARK: - Helpers

    private func createFiles(_ names: [String]) throws {
        for name in names {
            let url = tempDir.appendingPathComponent(name)
            try "test".write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

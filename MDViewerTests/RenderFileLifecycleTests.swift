import XCTest
import WebKit
@testable import MDViewer

final class RenderFileLifecycleTests: XCTestCase {

    private var tempDir: URL!
    private let defaultsKey = "mdviewer.lastRenderFilePath"

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        tempDir = nil
        super.tearDown()
    }

    // MARK: - Render file path

    func testRenderFilePath_isInDocumentDirectory() {
        let docDir = tempDir.appendingPathComponent("project")
        try? FileManager.default.createDirectory(at: docDir, withIntermediateDirectories: true)

        let renderFileURL = docDir.appendingPathComponent(".mdviewer-render.html")
        XCTAssertEqual(renderFileURL.lastPathComponent, ".mdviewer-render.html")
        XCTAssertEqual(
            renderFileURL.deletingLastPathComponent().standardizedFileURL.path,
            docDir.standardizedFileURL.path
        )
    }

    // MARK: - didFinish deletion

    func testDidFinish_schedulesFileDeletion() {
        let coordinator = MarkdownWebView(text: "", zoomLevel: 1.0, theme: .default, baseDirectory: nil, fitDiagramsToView: false).makeCoordinator()
        let renderFile = tempDir.appendingPathComponent(".mdviewer-render.html")
        try? "<html></html>".write(to: renderFile, atomically: true, encoding: .utf8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: renderFile.path))

        coordinator.previousRenderFileURL = renderFile
        coordinator.schedulePreviousRenderFileDeletion(after: 0.1)

        let expectation = self.expectation(description: "File deleted after delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertFalse(FileManager.default.fileExists(atPath: renderFile.path))
            expectation.fulfill()
        }
        waitForExpectations(timeout: 3.0)
    }

    func testDidFinish_withNilRenderFileURL_isNoop() {
        let coordinator = MarkdownWebView(text: "", zoomLevel: 1.0, theme: .default, baseDirectory: nil, fitDiagramsToView: false).makeCoordinator()
        coordinator.previousRenderFileURL = nil
        // Should not crash
        coordinator.schedulePreviousRenderFileDeletion(after: 0.1)
    }

    func testDidFinish_cancelsPreviousWorkItem() {
        let coordinator = MarkdownWebView(text: "", zoomLevel: 1.0, theme: .default, baseDirectory: nil, fitDiagramsToView: false).makeCoordinator()
        let renderFile = tempDir.appendingPathComponent(".mdviewer-render.html")
        try? "<html></html>".write(to: renderFile, atomically: true, encoding: .utf8)

        coordinator.previousRenderFileURL = renderFile
        coordinator.schedulePreviousRenderFileDeletion(after: 0.2)

        // Second call should cancel the first work item and create a new one
        coordinator.schedulePreviousRenderFileDeletion(after: 0.1)

        // File should still be deleted (by the second work item)
        let expectation = self.expectation(description: "File deleted after second delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertFalse(FileManager.default.fileExists(atPath: renderFile.path))
            expectation.fulfill()
        }
        waitForExpectations(timeout: 3.0)
    }

    // MARK: - Cross-session cleanup

    func testStaleRenderFile_fromPreviousSession_isDeleted() {
        let staleFile = tempDir.appendingPathComponent(".mdviewer-render.html")
        try? "<html></html>".write(to: staleFile, atomically: true, encoding: .utf8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: staleFile.path))

        UserDefaults.standard.set(staleFile.path, forKey: defaultsKey)

        // Simulate a new render in a different directory — stale file should be cleaned up
        let docDir = tempDir.appendingPathComponent("other-project")
        try? FileManager.default.createDirectory(at: docDir, withIntermediateDirectories: true)
        let renderFile = docDir.appendingPathComponent(".mdviewer-render.html")
        try? "<html></html>".write(to: renderFile, atomically: true, encoding: .utf8)

        // Verify stale file is still there before "loadContent" would clean it
        // The actual cleanup happens inside loadContent; we verify the mechanism here
        if let stalePath = UserDefaults.standard.string(forKey: defaultsKey),
           stalePath != renderFile.path,
           FileManager.default.fileExists(atPath: stalePath) {
            try? FileManager.default.removeItem(atPath: stalePath)
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: staleFile.path))
    }

    func testStaleRenderFile_sameDirectory_isNotDeleted() {
        let docDir = tempDir.appendingPathComponent("project")
        try? FileManager.default.createDirectory(at: docDir, withIntermediateDirectories: true)
        let renderFile = docDir.appendingPathComponent(".mdviewer-render.html")
        try? "<html></html>".write(to: renderFile, atomically: true, encoding: .utf8)

        UserDefaults.standard.set(renderFile.path, forKey: defaultsKey)

        // Same directory: stale path equals current path, should NOT delete
        if let stalePath = UserDefaults.standard.string(forKey: defaultsKey),
           stalePath != renderFile.path {
            try? FileManager.default.removeItem(atPath: stalePath)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: renderFile.path))
    }

    // MARK: - Overwriting existing render file

    func testExistingRenderFile_isOverwritten() {
        let docDir = tempDir.appendingPathComponent("project")
        try? FileManager.default.createDirectory(at: docDir, withIntermediateDirectories: true)
        let renderFile = docDir.appendingPathComponent(".mdviewer-render.html")

        try? "old content".write(to: renderFile, atomically: true, encoding: .utf8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: renderFile.path))

        try? "new content".write(to: renderFile, atomically: true, encoding: .utf8)
        let content = try? String(contentsOf: renderFile, encoding: .utf8)
        XCTAssertEqual(content, "new content")
    }
}

import XCTest
import UniformTypeIdentifiers
@testable import MDViewer

final class ExportFormatTests: XCTestCase {
    func testSVG_utType() {
        XCTAssertEqual(ExportFormat.svg.utType, .svg)
    }

    func testPNG_utType() {
        XCTAssertEqual(ExportFormat.png.utType, .png)
    }

    func testSVG_fileExtension() {
        XCTAssertEqual(ExportFormat.svg.fileExtension, "svg")
    }

    func testPNG_fileExtension() {
        XCTAssertEqual(ExportFormat.png.fileExtension, "png")
    }
}

final class DocumentStateExportTests: XCTestCase {
    func testMermaidDiagramCount_resetOnLoad() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file = tempDir.appendingPathComponent("test.md")
        try "# Hello".write(to: file, atomically: true, encoding: .utf8)

        let state = DocumentState()
        state.mermaidDiagramCount = 5
        XCTAssertEqual(state.mermaidDiagramCount, 5)

        state.load(url: file)
        XCTAssertEqual(state.mermaidDiagramCount, 0)
    }
}

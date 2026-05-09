import XCTest
import AppKit
import WebKit
@testable import MDViewer

final class DocumentStateRevealTests: XCTestCase {

    func testRevealInFinder_withCurrentURL_callsWorkspace() {
        let state = DocumentState()
        // Use the app bundle path as a known-existing URL — it's always present
        let url = Bundle.main.bundleURL
        state.load(url: url)

        // We can't assert NSWorkspace was actually called (no mocking in this project),
        // but we verify the method doesn't crash and currentURL is set.
        XCTAssertNotNil(state.currentURL)
        state.revealInFinder() // exercises the path
    }

    func testRevealInFinder_withNoCurrentURL_isNoop() {
        let state = DocumentState()
        XCTAssertNil(state.currentURL)
        state.revealInFinder() // should not crash
    }
}

final class LinkNavigationPolicyTests: XCTestCase {

    // MARK: - linkActivated

    func testLinkActivated_httpURL_cancelsAndReturnsURL() {
        let url = URL(string: "http://example.com")!
        let (policy, external) = linkNavigationPolicy(for: url, navigationType: .linkActivated)
        XCTAssertEqual(policy, .cancel, "http link-activated navigation must be cancelled to prevent internal navigation")
        XCTAssertEqual(external, url, "http URL must be returned so it can be opened in the OS browser")
    }

    func testLinkActivated_httpsURL_cancelsAndReturnsURL() {
        let url = URL(string: "https://example.com/path?q=1")!
        let (policy, external) = linkNavigationPolicy(for: url, navigationType: .linkActivated)
        XCTAssertEqual(policy, .cancel)
        XCTAssertEqual(external, url)
    }

    func testLinkActivated_mailtoURL_cancelsAndReturnsURL() {
        // mailto: links are common in Markdown and should open in the OS mail client.
        let url = URL(string: "mailto:user@example.com")!
        let (policy, external) = linkNavigationPolicy(for: url, navigationType: .linkActivated)
        XCTAssertEqual(policy, .cancel, "mailto link-activated navigation must be cancelled to prevent internal navigation")
        XCTAssertEqual(external, url, "mailto URL must be returned so it can be opened in the OS mail client")
    }

    func testLinkActivated_fileURL_cancelsAndReturnsNil() {
        // file:// links are intentionally blocked and must NOT be opened externally.
        // Security: untrusted Markdown should not be able to open arbitrary local paths
        // in the OS via NSWorkspace.
        let url = URL(string: "file:///some/doc.md")!
        let (policy, external) = linkNavigationPolicy(for: url, navigationType: .linkActivated)
        XCTAssertEqual(policy, .cancel)
        XCTAssertNil(external, "file:// links must not be opened in the OS browser")
    }

    // MARK: - fragment / anchor jumps

    func testLinkActivated_fragmentOnlyURL_allows() {
        // Footnote references like #fn-1 and back-links like #fnref-1 must work.
        let url = URL(string: "file:///path/to/dir/#fn-1")!
        let (policy, external) = linkNavigationPolicy(for: url, navigationType: .linkActivated)
        XCTAssertEqual(policy, .allow, "In-page anchor jumps should be allowed")
        XCTAssertNil(external)
    }

    func testLinkActivated_fragmentOnFileURL_blocks() {
        // Links to other files with fragments (e.g. other.md#section) should NOT be
        // allowed here — they fall through to tier 2 for MarkdownLinkResolver handling.
        let url = URL(string: "file:///path/to/other.md#section")!
        let (policy, external) = linkNavigationPolicy(for: url, navigationType: .linkActivated)
        XCTAssertEqual(policy, .cancel, "File links with fragments must not be auto-allowed")
        XCTAssertNil(external)
    }

    func testLinkActivated_fragmentOnHttpURL_blocksAndOpensExternally() {
        // External links with fragments should still open in the OS browser.
        let url = URL(string: "https://example.com/page#section")!
        let (policy, external) = linkNavigationPolicy(for: url, navigationType: .linkActivated)
        XCTAssertEqual(policy, .cancel)
        XCTAssertEqual(external, url)
    }

    func testLinkActivated_nilURL_cancelsAndReturnsNil() {
        let (policy, external) = linkNavigationPolicy(for: nil, navigationType: .linkActivated)
        XCTAssertEqual(policy, .cancel)
        XCTAssertNil(external)
    }

    // MARK: - other (initial HTML load)

    func testOtherNavigation_allowsAndReturnsNil() {
        // The initial loadHTMLString call fires a navigation of type .other.
        let url = URL(string: "about:blank")
        let (policy, external) = linkNavigationPolicy(for: url, navigationType: .other)
        XCTAssertEqual(policy, .allow, "Initial HTML load (.other) must be allowed")
        XCTAssertNil(external)
    }

    // MARK: - other navigation types

    func testBackForwardNavigation_cancelsAndReturnsNil() {
        let url = URL(string: "https://example.com")!
        let (policy, external) = linkNavigationPolicy(for: url, navigationType: .backForward)
        XCTAssertEqual(policy, .cancel)
        XCTAssertNil(external)
    }

    func testReloadNavigation_cancelsAndReturnsNil() {
        let url = URL(string: "https://example.com")!
        let (policy, external) = linkNavigationPolicy(for: url, navigationType: .reload)
        XCTAssertEqual(policy, .cancel)
        XCTAssertNil(external)
    }

    func testFormSubmittedNavigation_cancelsAndReturnsNil() {
        let url = URL(string: "https://example.com")!
        let (policy, external) = linkNavigationPolicy(for: url, navigationType: .formSubmitted)
        XCTAssertEqual(policy, .cancel)
        XCTAssertNil(external)
    }
}

// MARK: - MarkdownLinkResolver Tests

final class MarkdownLinkResolverTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    // MARK: resolve

    func testResolve_relativePath_resolvesAgainstBaseDirectory() {
        let base = tempDir.appendingPathComponent("docs")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let url = URL(string: "guide.md")!
        let resolver = MarkdownLinkResolver(baseDirectory: base)
        let resolved = resolver.resolve(url)
        XCTAssertEqual(resolved, base.appendingPathComponent("guide.md").standardizedFileURL)
    }

    func testResolve_relativePathWithDot_resolvesAgainstBaseDirectory() {
        let base = tempDir.appendingPathComponent("docs")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let url = URL(string: "./guide.md")!
        let resolver = MarkdownLinkResolver(baseDirectory: base)
        let resolved = resolver.resolve(url)
        XCTAssertEqual(resolved, base.appendingPathComponent("guide.md").standardizedFileURL)
    }

    func testResolve_relativeParentPath_resolvesAgainstBaseDirectory() {
        let base = tempDir.appendingPathComponent("docs/subdir")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let url = URL(string: "../guide.md")!
        let resolver = MarkdownLinkResolver(baseDirectory: base)
        let resolved = resolver.resolve(url)
        let expected = tempDir.appendingPathComponent("docs/guide.md").standardizedFileURL
        XCTAssertEqual(resolved, expected)
    }

    func testResolve_absolutePath_standardizes() {
        let url = URL(fileURLWithPath: "/Users/alice/docs/file.md")
        let resolver = MarkdownLinkResolver(baseDirectory: tempDir)
        let resolved = resolver.resolve(url)
        XCTAssertEqual(resolved, url.standardizedFileURL)
    }

    func testResolve_absolutePathWithFileScheme_standardizes() {
        let url = URL(string: "file:///Users/alice/docs/file.md")!
        let resolver = MarkdownLinkResolver(baseDirectory: tempDir)
        let resolved = resolver.resolve(url)
        XCTAssertEqual(resolved, url.standardizedFileURL)
    }

    // MARK: isMarkdownFile

    func testIsMarkdownFile_mdExtension_returnsTrue() {
        let url = URL(fileURLWithPath: "/path/to/file.md")
        let resolver = MarkdownLinkResolver(baseDirectory: nil)
        XCTAssertTrue(resolver.isMarkdownFile(url))
    }

    func testIsMarkdownFile_markdownExtension_returnsTrue() {
        let url = URL(fileURLWithPath: "/path/to/file.markdown")
        let resolver = MarkdownLinkResolver(baseDirectory: nil)
        XCTAssertTrue(resolver.isMarkdownFile(url))
    }

    func testIsMarkdownFile_mdownExtension_returnsTrue() {
        let url = URL(fileURLWithPath: "/path/to/file.mdown")
        let resolver = MarkdownLinkResolver(baseDirectory: nil)
        XCTAssertTrue(resolver.isMarkdownFile(url))
    }

    func testIsMarkdownFile_mkdExtension_returnsTrue() {
        let url = URL(fileURLWithPath: "/path/to/file.mkd")
        let resolver = MarkdownLinkResolver(baseDirectory: nil)
        XCTAssertTrue(resolver.isMarkdownFile(url))
    }

    func testIsMarkdownFile_caseInsensitive_uppercaseMD_returnsTrue() {
        let url = URL(fileURLWithPath: "/path/to/file.MD")
        let resolver = MarkdownLinkResolver(baseDirectory: nil)
        XCTAssertTrue(resolver.isMarkdownFile(url))
    }

    func testIsMarkdownFile_pngExtension_returnsFalse() {
        let url = URL(fileURLWithPath: "/path/to/image.png")
        let resolver = MarkdownLinkResolver(baseDirectory: nil)
        XCTAssertFalse(resolver.isMarkdownFile(url))
    }

    func testIsMarkdownFile_noExtension_returnsFalse() {
        let url = URL(fileURLWithPath: "/path/to/README")
        let resolver = MarkdownLinkResolver(baseDirectory: nil)
        XCTAssertFalse(resolver.isMarkdownFile(url))
    }

    // MARK: isWithinBaseDirectory

    func testIsWithinBaseDirectory_subPath_returnsTrue() {
        let base = tempDir.appendingPathComponent("docs")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let url = base.appendingPathComponent("guide.md")
        let resolver = MarkdownLinkResolver(baseDirectory: base)
        XCTAssertTrue(resolver.isWithinBaseDirectory(url))
    }

    func testIsWithinBaseDirectory_nestedSubPath_returnsTrue() {
        let base = tempDir.appendingPathComponent("docs")
        let nested = base.appendingPathComponent("subdir")
        try? FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let url = nested.appendingPathComponent("guide.md")
        let resolver = MarkdownLinkResolver(baseDirectory: base)
        XCTAssertTrue(resolver.isWithinBaseDirectory(url))
    }

    func testIsWithinBaseDirectory_exactBasePath_returnsTrue() {
        let base = tempDir.appendingPathComponent("docs")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let resolver = MarkdownLinkResolver(baseDirectory: base)
        XCTAssertTrue(resolver.isWithinBaseDirectory(base))
    }

    func testIsWithinBaseDirectory_traversalOutsideBase_returnsFalse() {
        let base = tempDir.appendingPathComponent("docs")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let url = tempDir.appendingPathComponent("secret.md")
        let resolver = MarkdownLinkResolver(baseDirectory: base)
        XCTAssertFalse(resolver.isWithinBaseDirectory(url))
    }

    func testIsWithinBaseDirectory_traversalViaParentPath_returnsFalse() {
        let base = tempDir.appendingPathComponent("docs")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        // Resolve a relative path that escapes the base directory
        let url = URL(fileURLWithPath: "../../../etc/passwd", relativeTo: base).standardizedFileURL
        let resolver = MarkdownLinkResolver(baseDirectory: base)
        XCTAssertFalse(resolver.isWithinBaseDirectory(url))
    }

    func testIsWithinBaseDirectory_nilBaseDirectory_returnsFalse() {
        let url = tempDir.appendingPathComponent("file.md")
        let resolver = MarkdownLinkResolver(baseDirectory: nil)
        XCTAssertFalse(resolver.isWithinBaseDirectory(url))
    }

    func testIsWithinBaseDirectory_prefixSpoofing_returnsFalse() {
        let base = tempDir.appendingPathComponent("docs")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        // /foo/barbaz should not match prefix /foo/bar
        let url = tempDir.appendingPathComponent("docsbackup/file.md")
        let resolver = MarkdownLinkResolver(baseDirectory: base)
        XCTAssertFalse(resolver.isWithinBaseDirectory(url))
    }

    func testIsWithinBaseDirectory_symlinkEscapesBase_returnsFalse() throws {
        let base = tempDir.appendingPathComponent("docs")
        let outside = tempDir.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)

        let symlink = base.appendingPathComponent("link.md")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: outside)

        let resolver = MarkdownLinkResolver(baseDirectory: base)
        XCTAssertFalse(resolver.isWithinBaseDirectory(symlink))
    }

    // MARK: resolveAndValidate

    func testResolveAndValidate_validMarkdownInsideBase_returnsResolvedURL() {
        let base = tempDir.appendingPathComponent("docs")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let url = URL(string: "guide.md")!
        let resolver = MarkdownLinkResolver(baseDirectory: base)
        let result = resolver.resolveAndValidate(url)
        XCTAssertEqual(result, base.appendingPathComponent("guide.md").standardizedFileURL)
    }

    func testResolveAndValidate_traversalBlocked_returnsNil() {
        let base = tempDir.appendingPathComponent("docs")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let url = URL(fileURLWithPath: "../../../etc/passwd")
        let resolver = MarkdownLinkResolver(baseDirectory: base)
        let result = resolver.resolveAndValidate(url)
        XCTAssertNil(result)
    }

    func testResolveAndValidate_nonMarkdownBlocked_returnsNil() {
        let base = tempDir.appendingPathComponent("docs")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let url = URL(fileURLWithPath: "image.png")
        let resolver = MarkdownLinkResolver(baseDirectory: base)
        let result = resolver.resolveAndValidate(url)
        XCTAssertNil(result)
    }
}

import XCTest
import WebKit
@testable import MDViewer

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

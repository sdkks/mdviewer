import SwiftUI
import WebKit

// Extracted for testability: given a URL and WKNavigationType, return the navigation
// policy and (if the URL should open externally) the URL to open in the OS browser.
// Returns (.cancel, url) when the link should open externally,
// (.allow, nil) when the navigation should proceed inside WKWebView (initial load),
// and (.cancel, nil) for any other navigation that should be blocked.
func linkNavigationPolicy(
    for url: URL?,
    navigationType: WKNavigationType
) -> (WKNavigationActionPolicy, URL?) {
    switch navigationType {
    case .linkActivated:
        // Allow in-page anchor jumps (footnotes, TOC, etc.).
        // When baseURL is a directory, fragment-only links resolve to a path ending in /.
        if let url, let fragment = url.fragment, !fragment.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.fragment = nil
            if let cleanURL = components?.url,
               (cleanURL.absoluteString.hasSuffix("/") || cleanURL.path.isEmpty) {
                return (.allow, nil)
            }
        }
        // Open http/https and mailto/tel links externally via the OS.
        // file:// links are intentionally blocked: untrusted Markdown should not be
        // able to open arbitrary local paths in the OS (security boundary).
        // All other unrecognised schemes are blocked by default.
        if let url, let scheme = url.scheme {
            switch scheme {
            case "http", "https", "mailto", "tel":
                return (.cancel, url)
            default:
                return (.cancel, nil)
            }
        }
        return (.cancel, nil)
    case .other:
        // Allow the initial loadHTMLString navigation. Note: .other is also triggered
        // by JS-initiated navigations and iframes; this is acceptable here only because
        // the current template.html contains no JS redirects or iframes.
        return (.allow, nil)
    default:
        return (.cancel, nil)
    }
}

struct MarkdownWebView: NSViewRepresentable {
    let text: String
    let zoomLevel: Double
    let theme: Theme
    let baseDirectory: URL?
    let fitDiagramsToView: Bool
    @EnvironmentObject var documentState: DocumentState

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var documentState: DocumentState?
        var lastRenderedText: String?
        var lastRenderedTheme: String?
        var baseDirectory: URL?

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            switch message.name {
            case "mermaidCount":
                guard let count = message.body as? Int else { return }
                documentState?.mermaidDiagramCount = count
            case "mermaidPNGExport":
                guard let dict = message.body as? [String: Any],
                      let diagrams = dict["diagrams"] as? [[String: Any]] else { return }
                documentState?.completePNGExport(diagrams: diagrams)
            default:
                break
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Tier 1: scheme-level policy (unchanged)
            let (policy, externalURL) = linkNavigationPolicy(
                for: navigationAction.request.url,
                navigationType: navigationAction.navigationType
            )
            if let externalURL {
                NSWorkspace.shared.open(externalURL)
                decisionHandler(.cancel)
                return
            }

            // Tier 2: file:// markdown links (new)
            if let url = navigationAction.request.url,
               url.scheme == "file",
               navigationAction.navigationType == .linkActivated {
                let resolver = MarkdownLinkResolver(baseDirectory: baseDirectory)
                if let resolved = resolver.resolveAndValidate(url) {
                    openMarkdownFile(resolved)
                    decisionHandler(.cancel)
                    return
                }
            }

            decisionHandler(policy)
        }

        private func openMarkdownFile(_ url: URL) {
            NSDocumentController.shared.openDocument(
                withContentsOf: url,
                display: true
            ) { _, _, error in
                if let error {
                    DispatchQueue.main.async {
                        NSApplication.shared.presentError(error)
                    }
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        context.coordinator.documentState = documentState
        context.coordinator.baseDirectory = baseDirectory
        config.userContentController.add(context.coordinator, name: "mermaidCount")
        config.userContentController.add(context.coordinator, name: "mermaidPNGExport")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.pageZoom = zoomLevel
        loadContent(into: webView)

        // Store the webView reference on DocumentState for find command access.
        // Deferred to next run loop to avoid mutating state during view construction.
        DispatchQueue.main.async {
            self.documentState.webView = webView
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.pageZoom = zoomLevel
        context.coordinator.baseDirectory = baseDirectory

        let c = context.coordinator
        guard text != c.lastRenderedText || theme.id != c.lastRenderedTheme else { return }
        c.lastRenderedText = text
        c.lastRenderedTheme = theme.id
        loadContent(into: nsView)
    }

    private func loadContent(into webView: WKWebView) {
        guard let templateURL = Bundle.main.url(forResource: "template", withExtension: "html"),
              let markedURL = Bundle.main.url(forResource: "marked.min", withExtension: "js"),
              let mermaidURL = Bundle.main.url(forResource: "mermaid.min", withExtension: "js"),
              var html = try? String(contentsOf: templateURL, encoding: .utf8),
              let markedJS = try? String(contentsOf: markedURL, encoding: .utf8),
              let mermaidJS = try? String(contentsOf: mermaidURL, encoding: .utf8)
        else { return }

        let highlightURL = Bundle.main.url(forResource: "highlight.min", withExtension: "js")
        let highlightCSSURL = Bundle.main.url(forResource: "highlight-\(theme.highlightTheme).min", withExtension: "css")
        let highlightJS = highlightURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        let highlightCSS = highlightCSSURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""

        let footnoteURL = Bundle.main.url(forResource: "marked-footnote.min", withExtension: "js")
        let svgPanZoomURL = Bundle.main.url(forResource: "svg-pan-zoom.min", withExtension: "js")
        let footnoteJS = footnoteURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        let svgPanZoomJS = svgPanZoomURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""

        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "<", with: "\\u003C")

        html = html
            .replacingOccurrences(of: "{{THEME_CSS}}", with: theme.colors.cssVariables())
            .replacingOccurrences(of: "{{MARKED_JS}}", with: markedJS)
            .replacingOccurrences(of: "{{MERMAID_JS}}", with: mermaidJS)
            .replacingOccurrences(of: "{{MARKED_FOOTNOTE_JS}}", with: footnoteJS)
            .replacingOccurrences(of: "{{SVG_PAN_ZOOM_JS}}", with: svgPanZoomJS)
            .replacingOccurrences(of: "{{HIGHLIGHT_JS}}", with: highlightJS)
            .replacingOccurrences(of: "{{HIGHLIGHT_CSS}}", with: highlightCSS)
            .replacingOccurrences(of: "{{THEME_ID}}", with: theme.id)
            .replacingOccurrences(of: "{{FIT_DIAGRAMS}}", with: fitDiagramsToView ? "true" : "false")
            .replacingOccurrences(of: "{{MARKDOWN_CONTENT}}", with: escaped)

        // Use the document's directory as baseURL so relative file:// links resolve
        // correctly for inter-document navigation. Fall back to the template directory
        // when no document is open (e.g., unsaved new document).
        let baseURL = baseDirectory ?? templateURL.deletingLastPathComponent()
        webView.loadHTMLString(html, baseURL: baseURL)
    }
}

#Preview {
    MarkdownWebView(
        text: "# This is a test\n1. Test\n1. Test\n1. Test",
        zoomLevel: 1.0,
        theme: Theme.theme(for: "github-light", in: Theme.themes),
        baseDirectory: nil,
        fitDiagramsToView: true
    )
    .environmentObject(DocumentState())
}

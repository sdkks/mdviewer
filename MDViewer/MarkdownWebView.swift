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
    @EnvironmentObject var documentState: DocumentState

    class Coordinator: NSObject, WKNavigationDelegate {
        var lastRenderedText: String?
        var lastRenderedTheme: String?

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            let (policy, externalURL) = linkNavigationPolicy(
                for: navigationAction.request.url,
                navigationType: navigationAction.navigationType
            )
            if let externalURL {
                NSWorkspace.shared.open(externalURL)
            }
            decisionHandler(policy)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

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

        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        html = html
            .replacingOccurrences(of: "{{THEME_CSS}}", with: theme.colors.cssVariables())
            .replacingOccurrences(of: "{{MARKED_JS}}", with: markedJS)
            .replacingOccurrences(of: "{{MERMAID_JS}}", with: mermaidJS)
            .replacingOccurrences(of: "{{THEME_ID}}", with: theme.id)
            .replacingOccurrences(of: "{{MARKDOWN_CONTENT}}", with: escaped)

        webView.loadHTMLString(html, baseURL: templateURL.deletingLastPathComponent())
    }
}

#Preview {
    MarkdownWebView(text: "# This is a test\n1. Test\n1. Test\n1. Test", zoomLevel: 1.0, theme: Theme.theme(for: "github-light", in: Theme.themes))
        .environmentObject(DocumentState())
}

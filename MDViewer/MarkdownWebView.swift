import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let text: String
    let zoomLevel: Double
    let theme: Theme
    @EnvironmentObject var documentState: DocumentState

    class Coordinator: NSObject, WKNavigationDelegate {
        var lastRenderedText: String?
        var lastRenderedTheme: String?
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
              var html = try? String(contentsOf: templateURL, encoding: .utf8),
              let markedJS = try? String(contentsOf: markedURL, encoding: .utf8)
        else { return }

        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        html = html
            .replacingOccurrences(of: "{{THEME_CSS}}", with: theme.colors.cssVariables())
            .replacingOccurrences(of: "{{MARKED_JS}}", with: markedJS)
            .replacingOccurrences(of: "{{MARKDOWN_CONTENT}}", with: escaped)

        webView.loadHTMLString(html, baseURL: templateURL.deletingLastPathComponent())
    }
}

#Preview {
    MarkdownWebView(text: "# This is a test\n1. Test\n1. Test\n1. Test", zoomLevel: 1.0, theme: Theme.theme(for: "github-light", in: Theme.themes))
        .environmentObject(DocumentState())
}

import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let text: String
    let zoomLevel: Double
    let theme: Theme

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.pageZoom = zoomLevel
        loadContent(into: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.pageZoom = zoomLevel
        loadContent(into: webView)
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
}

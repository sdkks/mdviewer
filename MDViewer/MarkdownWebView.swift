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
        var previousRenderDirectory: URL?
        var previousRenderFileURL: URL?
        fileprivate var fileDeletionWorkItem: DispatchWorkItem?

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
            case "mermaidH1Headers":
                guard let nodes = message.body as? [[String: Any]] else {
                    NSLog("[mermaidH1Headers] failed to parse body: %@", String(describing: message.body))
                    return
                }
                let parsed = nodes.compactMap { dict -> HeaderNode? in
                    guard let text = dict["text"] as? String,
                          let id = dict["id"] as? String else { return nil }
                    let h2s = (dict["h2s"] as? [[String: String]])?.compactMap {
                        HeaderItem(text: $0["text"] ?? "", id: $0["id"] ?? "")
                    } ?? []
                    return HeaderNode(text: text, id: id, h2s: h2s)
                }
                NSLog("[mermaidH1Headers] received %d H1s with %d total H2s", parsed.count, parsed.reduce(0) { $0 + $1.h2s.count })
                documentState?.currentFileHeaders = parsed
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

        func schedulePreviousRenderFileDeletion(after delay: TimeInterval = 1) {
            fileDeletionWorkItem?.cancel()
            let url = previousRenderFileURL
            fileDeletionWorkItem = DispatchWorkItem { [weak self] in
                if let url {
                    try? FileManager.default.removeItem(at: url)
                }
                self?.fileDeletionWorkItem = nil
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: fileDeletionWorkItem!)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            schedulePreviousRenderFileDeletion()
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
        config.userContentController.add(context.coordinator, name: "mermaidH1Headers")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.pageZoom = zoomLevel
        loadContent(into: webView, coordinator: context.coordinator)

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
        loadContent(into: nsView, coordinator: c)
    }

    private func loadContent(into webView: WKWebView, coordinator: Coordinator) {
        guard let templateURL = Bundle.main.url(forResource: "template", withExtension: "html"),
              let markedURL = Bundle.main.url(forResource: "marked.min", withExtension: "js"),
              let mermaidURL = Bundle.main.url(forResource: "mermaid.min", withExtension: "js"),
              var html = try? String(contentsOf: templateURL, encoding: .utf8),
              let markedJS = try? String(contentsOf: markedURL, encoding: .utf8),
              let mermaidJS = try? String(contentsOf: mermaidURL, encoding: .utf8)
        else { return }

        let jsYamlURL = Bundle.main.url(forResource: "js-yaml.min", withExtension: "js")
        let jsYamlJS = jsYamlURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
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
            .replacingOccurrences(of: "{{JS_YAML_JS}}", with: jsYamlJS)
            .replacingOccurrences(of: "{{MARKED_JS}}", with: markedJS)
            .replacingOccurrences(of: "{{MERMAID_JS}}", with: mermaidJS)
            .replacingOccurrences(of: "{{MARKED_FOOTNOTE_JS}}", with: footnoteJS)
            .replacingOccurrences(of: "{{SVG_PAN_ZOOM_JS}}", with: svgPanZoomJS)
            .replacingOccurrences(of: "{{HIGHLIGHT_JS}}", with: highlightJS)
            .replacingOccurrences(of: "{{HIGHLIGHT_CSS}}", with: highlightCSS)
            .replacingOccurrences(of: "{{THEME_ID}}", with: theme.id)
            .replacingOccurrences(of: "{{FIT_DIAGRAMS}}", with: fitDiagramsToView ? "true" : "false")
            .replacingOccurrences(of: "{{MARKDOWN_CONTENT}}", with: escaped)

        let fallbackBaseURL = templateURL.deletingLastPathComponent()

        if let docDir = baseDirectory {
            let renderFileURL = docDir.appendingPathComponent(".mdviewer-render.html")

            // Cancel a pending deletion from a previous load so we don't delete the
            // new file before the current load completes.
            coordinator.fileDeletionWorkItem?.cancel()
            coordinator.fileDeletionWorkItem = nil

            // Cross-session cleanup: remove stale render file from a previous app launch.
            let defaults = UserDefaults.standard
            if let stalePath = defaults.string(forKey: "mdviewer.lastRenderFilePath"),
               stalePath != renderFileURL.path,
               FileManager.default.fileExists(atPath: stalePath) {
                try? FileManager.default.removeItem(atPath: stalePath)
            }

            // Remove any existing render file in the current directory (e.g. from a crash
            // or if the previous deletion didn't fire before the app quit).
            if FileManager.default.fileExists(atPath: renderFileURL.path) {
                try? FileManager.default.removeItem(at: renderFileURL)
            }

            do {
                try html.write(to: renderFileURL, atomically: true, encoding: .utf8)
                coordinator.previousRenderFileURL = renderFileURL
                coordinator.previousRenderDirectory = docDir
                defaults.set(renderFileURL.path, forKey: "mdviewer.lastRenderFilePath")
                webView.loadFileURL(renderFileURL, allowingReadAccessTo: docDir)
                return
            } catch {
                NSLog("[MarkdownWebView] Failed to write render file: \(error)")
                // Fall through to loadHTMLString fallback.
            }
        }

        // Fallback for unsaved new documents or when file write fails.
        webView.loadHTMLString(html, baseURL: fallbackBaseURL)
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

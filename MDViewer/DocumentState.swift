import Foundation
import AppKit
import WebKit
import Combine
import UniformTypeIdentifiers

enum FileSortOrder: String, CaseIterable {
    case alphabetical
    case dateModified
}

enum ExportFormat {
    case svg, png

    var utType: UTType {
        switch self {
        case .svg: return .svg
        case .png: return .png
        }
    }

    var fileExtension: String {
        switch self {
        case .svg: return "svg"
        case .png: return "png"
        }
    }
}

struct HeaderNode {
    let text: String
    let id: String
    let h2s: [HeaderItem]
}

struct HeaderItem {
    let text: String
    let id: String
}

final class DocumentState: ObservableObject {
    @Published var currentURL: URL?
    @Published var renderedText: String = ""
    @Published var sortOrder: FileSortOrder = .alphabetical
    @Published var showFindBar: Bool = false
    @Published var findText: String = ""
    @Published var findMatchFound: Bool? = nil  // nil = no search yet
    @Published var findCurrentIndex: Int = 0
    @Published var findTotalCount: Int = 0
    @Published var showSidebar: Bool = false
    @Published var mermaidDiagramCount: Int = 0
    @Published var currentFileHeaders: [HeaderNode] = []
    weak var webView: WKWebView?
    private var pendingScrollAnchor: String?

    func load(url: URL, scrollToAnchor anchor: String? = nil) {
        renderedText = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        currentURL = url.standardizedFileURL
        mermaidDiagramCount = 0      // reset; JS will repopulate after render
        currentFileHeaders = []      // reset; JS will repopulate after render
        dismissFind()
        pendingScrollAnchor = anchor
    }

    func scrollToAnchor(_ anchor: String) {
        // Use location.hash for reliable anchor scrolling in WKWebView.
        // scrollIntoView is unreliable inside loadHTMLString-backed views.
        let escaped = anchor
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let js = """
            (function() {
                var el = document.getElementById('\(escaped)');
                if (!el) return 'not found';
                location.hash = '#\(escaped)';
                return 'ok';
            })()
            """
        webView?.evaluateJavaScript(js) { result, error in
            if result as? String != "ok" {
                NSLog("scrollToAnchor failed for '%@': %@", anchor, String(describing: error))
            }
        }
    }

    func attemptPendingScroll() {
        guard let anchor = pendingScrollAnchor else { return }
        pendingScrollAnchor = nil
        // Give the webview a moment to finish rendering
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.scrollToAnchor(anchor)
        }
    }

    func navigatePrevious() {
        guard let current = currentURL else { return }
        let siblings = sibling(of: current)
        guard let idx = siblings.firstIndex(of: current), idx > 0 else { return }
        load(url: siblings[idx - 1])
    }

    func navigateNext() {
        guard let current = currentURL else { return }
        let siblings = sibling(of: current)
        guard let idx = siblings.firstIndex(of: current), idx < siblings.count - 1 else { return }
        load(url: siblings[idx + 1])
    }

    // Parse H1 and H2 headers from a Markdown file, skipping fenced code blocks.
    // Returns up to 20 H1 nodes, each with its nested H2s.
    static func parseHeaders(from url: URL) -> [HeaderNode] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var nodes: [HeaderNode] = []
        var currentH2s: [HeaderItem] = []
        var inCodeBlock = false
        var h1Count = 0

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inCodeBlock.toggle()
                continue
            }
            if inCodeBlock { continue }

            if trimmed.hasPrefix("## ") {
                let title = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                currentH2s.append(HeaderItem(text: title, id: slugify(title)))
            } else if trimmed.hasPrefix("# ") {
                if !nodes.isEmpty {
                    nodes[nodes.count - 1] = HeaderNode(
                        text: nodes[nodes.count - 1].text,
                        id: nodes[nodes.count - 1].id,
                        h2s: currentH2s
                    )
                }
                let title = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                nodes.append(HeaderNode(text: title, id: slugify(title), h2s: []))
                currentH2s = []
                h1Count += 1
                if h1Count >= 20 { break }
            }
        }
        if !nodes.isEmpty {
            nodes[nodes.count - 1] = HeaderNode(
                text: nodes[nodes.count - 1].text,
                id: nodes[nodes.count - 1].id,
                h2s: currentH2s
            )
        }
        return nodes
    }

    private static func slugify(_ text: String) -> String {
        // Match JS slugify: lowercase, trim, collapse spaces to '-', strip non-alphanumeric
        text.lowercased()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "[\\s]+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
    }

    func sibling(of url: URL) -> [URL] {
        let dir = url.deletingLastPathComponent()
        let mdExtensions = Set(["md", "markdown", "mdown", "mkd"])
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let mdFiles = files.filter { mdExtensions.contains($0.pathExtension.lowercased()) }
        switch sortOrder {
        case .alphabetical:
            return mdFiles.sorted { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }
        case .dateModified:
            return mdFiles.sorted {
                let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return d1 > d2
            }
        }
    }

    @Published var showFilePicker: Bool = false

    func activateFilePicker() {
        showFindBar = false   // mutual exclusion
        showFilePicker = true
    }

    func activateFind() {
        showFilePicker = false  // mutual exclusion
        showFindBar = true
    }

    // Count all case-insensitive matches in the rendered page text via JS.
    private func updateTotalCount(for query: String) {
        guard let webView = webView, !query.isEmpty else {
            findTotalCount = 0
            return
        }
        let escaped = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let js = """
        (function(){
            var t = document.body ? document.body.innerText : '';
            var m = t.match(new RegExp(\"\(escaped)\", 'gi'));
            return m ? m.length : 0;
        })()
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            DispatchQueue.main.async {
                self?.findTotalCount = (result as? Int) ?? 0
            }
        }
    }

    func startFind(query: String) {
        findCurrentIndex = 0
        findTotalCount = 0
        findMatchFound = nil
        updateTotalCount(for: query)
        guard let webView = webView, !query.isEmpty else { return }
        let config = WKFindConfiguration()
        config.wraps = true
        config.caseSensitive = false
        webView.find(query, configuration: config) { [weak self] result in
            guard let self else { return }
            self.findMatchFound = result.matchFound
            if result.matchFound { self.findCurrentIndex = 1 }
        }
    }

    func findNext() {
        guard let webView = webView, !findText.isEmpty else { return }
        let config = WKFindConfiguration()
        config.wraps = true
        config.caseSensitive = false
        webView.find(findText, configuration: config) { [weak self] result in
            guard let self else { return }
            self.findMatchFound = result.matchFound
            if result.matchFound {
                if self.findCurrentIndex >= self.findTotalCount {
                    self.findCurrentIndex = 1  // wrapped
                } else {
                    self.findCurrentIndex += 1
                }
            }
        }
    }

    func findPrevious() {
        guard let webView = webView, !findText.isEmpty else { return }
        let config = WKFindConfiguration()
        config.wraps = true
        config.caseSensitive = false
        config.backwards = true
        webView.find(findText, configuration: config) { [weak self] result in
            guard let self else { return }
            self.findMatchFound = result.matchFound
            if result.matchFound {
                if self.findCurrentIndex <= 1 {
                    self.findCurrentIndex = self.findTotalCount  // wrapped
                } else {
                    self.findCurrentIndex -= 1
                }
            }
        }
    }

    func revealInFinder() {
        guard let url = currentURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func dismissFind() {
        showFindBar = false
        findMatchFound = nil
        findCurrentIndex = 0
        findTotalCount = 0
        let query = findText
        findText = ""
        if !query.isEmpty, let webView = webView {
            webView.find("", configuration: WKFindConfiguration()) { _ in }
        }
    }

    // MARK: - Mermaid Diagram Export

    func exportMermaidDiagrams(format: ExportFormat) {
        guard let webView = webView else {
            presentExportAlert(message: "No web view available.")
            return
        }
        if format == .png {
            // PNG export is async — JS posts results back via mermaidPNGExport message handler.
            webView.evaluateJavaScript("window.startMermaidPNGExport()") { [weak self] _, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.presentExportAlert(message: "Failed to start PNG export: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            // SVG export is synchronous — JS returns an array of SVG strings.
            webView.evaluateJavaScript("window.exportMermaidSVGs()") { [weak self] result, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if let error = error {
                        self.presentExportAlert(message: "Failed to extract diagrams: \(error.localizedDescription)")
                        return
                    }
                    guard let diagrams = result as? [[String: Any]], !diagrams.isEmpty else {
                        self.presentExportAlert(message: "No Mermaid diagrams found in this document.")
                        return
                    }
                    self.exportDiagramsAsZip(diagrams: diagrams, format: format)
                }
            }
        }
    }

    func completePNGExport(diagrams: [[String: Any]]) {
        guard !diagrams.isEmpty else {
            presentExportAlert(message: "No Mermaid diagrams found in this document.")
            return
        }
        exportDiagramsAsZip(diagrams: diagrams, format: .png)
    }

    private func exportDiagramsAsZip(diagrams: [[String: Any]], format: ExportFormat) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let zipName = "mermaid-diagrams-\(format.fileExtension).zip"

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            for (index, diagram) in diagrams.enumerated() {
                let filename = "diagram-\(index + 1).\(format.fileExtension)"
                let fileURL = tempDir.appendingPathComponent(filename)

                switch format {
                case .svg:
                    guard let svgString = diagram["svg"] as? String else { continue }
                    try svgString.write(to: fileURL, atomically: true, encoding: .utf8)
                case .png:
                    guard let pngDataUrl = diagram["png"] as? String, !pngDataUrl.isEmpty else { continue }
                    let base64Prefix = "data:image/png;base64,"
                    let base64String = pngDataUrl.hasPrefix(base64Prefix)
                        ? String(pngDataUrl.dropFirst(base64Prefix.count))
                        : pngDataUrl
                    guard let data = Data(base64Encoded: base64String) else { continue }
                    try data.write(to: fileURL)
                }
            }

            let zipURL = tempDir.appendingPathComponent(zipName)
            let fileNames = diagrams.indices.map { "diagram-\($0 + 1).\(format.fileExtension)" }
            try createZip(at: zipURL, sourceDir: tempDir, files: fileNames)

            let panel = NSSavePanel()
            panel.allowedContentTypes = [.zip]
            panel.nameFieldStringValue = zipName
            panel.directoryURL = self.currentURL?.deletingLastPathComponent()
            panel.begin { [weak self] result in
                guard let self = self, result == .OK, let destinationURL = panel.url else {
                    try? FileManager.default.removeItem(at: tempDir)
                    return
                }
                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(at: zipURL, to: destinationURL)
                } catch {
                    self.presentExportAlert(message: "Failed to save ZIP: \(error.localizedDescription)")
                }
                try? FileManager.default.removeItem(at: tempDir)
            }
        } catch {
            presentExportAlert(message: "Failed to create export: \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    private func createZip(at zipURL: URL, sourceDir: URL, files: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-j", zipURL.path] + files.map { sourceDir.appendingPathComponent($0).path }
        process.currentDirectoryURL = sourceDir

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw NSError(domain: "MDViewer", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "zip failed: \(output)"])
        }
    }

    private func presentExportAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Export Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

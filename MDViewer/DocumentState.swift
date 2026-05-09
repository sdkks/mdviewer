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
    weak var webView: WKWebView?

    func load(url: URL) {
        renderedText = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        currentURL = url.standardizedFileURL
        mermaidDiagramCount = 0   // reset; JS will repopulate after render
        dismissFind()
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
                if diagrams.count == 1 {
                    self.saveSingleDiagram(diagrams[0], format: format)
                } else {
                    self.showExportSelectionPanel(diagrams, format: format)
                }
            }
        }
    }

    func exportFilename(forIndex index: Int, total: Int, format: ExportFormat) -> String {
        if total == 1 {
            return "diagram.\(format.fileExtension)"
        } else {
            return "diagram-\(index + 1).\(format.fileExtension)"
        }
    }

    private func saveSingleDiagram(_ diagram: [String: Any], format: ExportFormat) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.utType]
        panel.nameFieldStringValue = exportFilename(forIndex: 0, total: 1, format: format)
        panel.directoryURL = currentURL?.deletingLastPathComponent()
        panel.begin { [weak self] result in
            guard let self = self, result == .OK, let url = panel.url else { return }
            if let svgString = diagram["svg"] as? String {
                self.saveDiagram(svgString: svgString, format: format, to: url)
            }
        }
    }

    private func showExportSelectionPanel(_ diagrams: [[String: Any]], format: ExportFormat) {
        let total = diagrams.count
        func presentNext(index: Int) {
            guard index < total else { return }
            let panel = NSSavePanel()
            panel.allowedContentTypes = [format.utType]
            panel.nameFieldStringValue = exportFilename(forIndex: index, total: total, format: format)
            panel.directoryURL = currentURL?.deletingLastPathComponent()
            panel.title = "Export Diagram \(index + 1) of \(total)"
            panel.begin { [weak self] result in
                guard let self = self else { return }
                if result == .OK, let url = panel.url {
                    if let svgString = diagrams[index]["svg"] as? String {
                        self.saveDiagram(svgString: svgString, format: format, to: url)
                    }
                }
                presentNext(index: index + 1)
            }
        }
        presentNext(index: 0)
    }

    private func saveDiagram(svgString: String, format: ExportFormat, to url: URL) {
        switch format {
        case .svg:
            try? svgString.write(to: url, atomically: true, encoding: .utf8)
        case .png:
            convertSVGToPNG(svgString, saveTo: url)
        }
    }

    private func convertSVGToPNG(_ svgString: String, saveTo url: URL) {
        guard let data = svgString.data(using: .utf8),
              let image = NSImage(data: data),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            // Best-effort: silently skip if conversion fails
            return
        }
        try? pngData.write(to: url)
    }

    private func presentExportAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Export Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

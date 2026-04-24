import Foundation
import AppKit
import WebKit
import Combine

enum FileSortOrder: String, CaseIterable {
    case alphabetical
    case dateModified
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
    weak var webView: WKWebView?

    func load(url: URL) {
        renderedText = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        currentURL = url
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

    private func sibling(of url: URL) -> [URL] {
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
}

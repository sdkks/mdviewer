import Foundation
import SwiftUI

@MainActor
final class FilePickerState: ObservableObject {
    @Published var inputText: String = ""
    @Published var candidates: [PathCandidate] = []
    @Published var selectedIndex: Int? = nil

    private var enumerationTask: Task<Void, Never>?
    let anchorDirectory: URL
    var onCommit: (URL) -> Void
    var onDismiss: () -> Void

    init(anchorDirectory: URL, onCommit: @escaping (URL) -> Void, onDismiss: @escaping () -> Void) {
        self.anchorDirectory = anchorDirectory
        self.onCommit = onCommit
        self.onDismiss = onDismiss
    }

    // MARK: - Directory resolution

    /// Resolves the directory and filename-prefix components out of the current inputText.
    private func resolvedDirectoryAndPrefix() -> (directory: URL, prefix: String) {
        let text = inputText

        // Split on last "/"
        if let slashRange = text.range(of: "/", options: .backwards) {
            let dirSegment = String(text[text.startIndex..<slashRange.upperBound])  // includes trailing "/"
            let prefix = String(text[slashRange.upperBound...])

            let expandedDir: String
            if dirSegment.hasPrefix("~/") {
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                expandedDir = home + "/" + String(dirSegment.dropFirst(2))
            } else {
                expandedDir = dirSegment
            }

            let resolved = URL(fileURLWithPath: expandedDir, relativeTo: anchorDirectory).standardizedFileURL

            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDir)
            if exists && isDir.boolValue {
                return (resolved, prefix)
            } else {
                return (anchorDirectory, prefix)
            }
        } else {
            // No slash at all — use anchorDirectory, whole text is the prefix
            return (anchorDirectory, text)
        }
    }

    // MARK: - Enumeration

    func enumerateForCurrentInput() {
        enumerationTask?.cancel()
        let (directory, prefix) = resolvedDirectoryAndPrefix()

        enumerationTask = Task {
            try? await Task.sleep(nanoseconds: 80_000_000) // 80ms debounce
            guard !Task.isCancelled else { return }
            self.candidates = []
            self.selectedIndex = nil
            let results = await PathEnumerator.candidates(in: directory, prefix: prefix)
            guard !Task.isCancelled else { return }
            self.candidates = Array(results.prefix(100))
        }
    }

    // MARK: - Tab completion

    func tabComplete() {
        let dirCandidates = candidates.filter { $0.isDirectory }

        if dirCandidates.isEmpty {
            // OQ-2 resolution (FR-3-20): no directories — cycle selection among files
            selectNext()
            return
        }

        // Compute longest common prefix of directory displayNames
        let names = dirCandidates.map { $0.displayName }
        guard let lcp = longestCommonPrefix(of: names) else { return }

        // The current filename prefix is the portion after the last "/"
        let (_, currentPrefix) = resolvedDirectoryAndPrefix()

        // Only replace if the LCP is strictly longer than what we already have
        guard lcp.count > currentPrefix.count else { return }

        // Replace the last segment in inputText with the LCP
        if let slashRange = inputText.range(of: "/", options: .backwards) {
            let dirPart = String(inputText[inputText.startIndex..<slashRange.upperBound])
            // LCP includes the trailing "/" if it is a complete directory name
            inputText = dirPart + lcp
        } else {
            inputText = lcp
        }

        enumerateForCurrentInput()
    }

    private func longestCommonPrefix(of strings: [String]) -> String? {
        guard let first = strings.first else { return nil }
        var prefix = first
        for s in strings.dropFirst() {
            while !s.lowercased().hasPrefix(prefix.lowercased()) {
                if prefix.isEmpty { return nil }
                prefix = String(prefix.dropLast())
            }
        }
        return prefix
    }

    // MARK: - Selection navigation

    func selectNext() {
        guard !candidates.isEmpty else { return }
        if let idx = selectedIndex {
            selectedIndex = (idx + 1 >= candidates.count) ? 0 : idx + 1
        } else {
            selectedIndex = 0
        }
    }

    func selectPrev() {
        guard !candidates.isEmpty else { return }
        if let idx = selectedIndex {
            selectedIndex = (idx == 0) ? nil : idx - 1
        }
    }

    // MARK: - Commit / dismiss

    func commit() {
        guard let idx = selectedIndex, idx < candidates.count else { return }
        let candidate = candidates[idx]
        if candidate.isDirectory {
            // Navigate into the directory: replace the last path segment with the full directory name
            if let slashRange = inputText.range(of: "/", options: .backwards) {
                let dirPart = String(inputText[inputText.startIndex..<slashRange.upperBound])
                inputText = dirPart + candidate.displayName
            } else {
                // No slash — bare prefix or empty; replace entirely with the selected directory
                inputText = candidate.displayName
            }
            enumerateForCurrentInput()
        } else {
            onCommit(candidate.url)
        }
    }

    /// Commit a specific candidate directly (used by mouse click in the list).
    func commit(candidate: PathCandidate) {
        if let idx = candidates.firstIndex(of: candidate) {
            selectedIndex = idx
        }
        commit()
    }

    func dismiss() {
        enumerationTask?.cancel()
        onDismiss()
    }
}

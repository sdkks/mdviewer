import Foundation

enum PathEnumerator {
    static let mdExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    /// Returns PathCandidates under `directory` matching `prefix` via fuzzy scoring.
    /// Directories are always included (any name). Files must have a recognised markdown extension.
    /// On any error (permissions, missing path), returns an empty array.
    static func candidates(in directory: URL, prefix: String) async -> [PathCandidate] {
        let items: [URL]
        do {
            items = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            )
        } catch {
            return []
        }

        var dirs: [PathCandidate] = []
        var files: [PathCandidate] = []

        for item in items {
            let name = item.lastPathComponent
            let ext = item.pathExtension.lowercased()

            var isDir = false
            if let vals = try? item.resourceValues(forKeys: [.isDirectoryKey]) {
                isDir = vals.isDirectory ?? false
            }

            // Apply prefix filter
            if !prefix.isEmpty {
                guard let fuzzy = FuzzyMatcher.score(prefix, against: name) else { continue }
                if isDir {
                    dirs.append(PathCandidate(
                        url: item,
                        displayName: name + "/",
                        isDirectory: true,
                        score: fuzzy.score,
                        matchedIndices: fuzzy.matchedIndices
                    ))
                } else if mdExtensions.contains(ext) {
                    files.append(PathCandidate(
                        url: item,
                        displayName: name,
                        isDirectory: false,
                        score: fuzzy.score,
                        matchedIndices: fuzzy.matchedIndices
                    ))
                }
            } else {
                if isDir {
                    dirs.append(PathCandidate(
                        url: item,
                        displayName: name + "/",
                        isDirectory: true,
                        score: 0,
                        matchedIndices: []
                    ))
                } else if mdExtensions.contains(ext) {
                    files.append(PathCandidate(
                        url: item,
                        displayName: name,
                        isDirectory: false,
                        score: 0,
                        matchedIndices: []
                    ))
                }
            }
        }

        dirs.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.displayName.lowercased() < $1.displayName.lowercased()
        }
        files.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.displayName.lowercased() < $1.displayName.lowercased()
        }

        return dirs + files
    }
}

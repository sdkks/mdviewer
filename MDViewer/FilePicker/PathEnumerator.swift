import Foundation

enum PathEnumerator {
    static let mdExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    /// Returns PathCandidates under `directory` whose last path segment starts with `prefix` (case-insensitive).
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

            // Apply prefix filter (empty prefix matches everything)
            if !prefix.isEmpty {
                guard name.lowercased().contains(prefix.lowercased()) else { continue }
            }

            if isDir {
                dirs.append(PathCandidate(url: item, displayName: name + "/", isDirectory: true))
            } else if mdExtensions.contains(ext) {
                files.append(PathCandidate(url: item, displayName: name, isDirectory: false))
            }
        }

        dirs.sort { $0.displayName.lowercased() < $1.displayName.lowercased() }
        files.sort { $0.displayName.lowercased() < $1.displayName.lowercased() }

        return dirs + files
    }
}

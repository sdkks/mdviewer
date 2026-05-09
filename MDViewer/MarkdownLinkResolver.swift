import Foundation

struct MarkdownLinkResolver {
    let baseDirectory: URL?

    func resolveAndValidate(_ url: URL) -> URL? {
        guard let resolved = resolve(url) else { return nil }
        guard isMarkdownFile(resolved) else { return nil }
        guard isWithinBaseDirectory(resolved) else { return nil }
        return resolved
    }

    func resolve(_ url: URL) -> URL? {
        // If the URL already has an absolute file path, just standardize it.
        // In practice WKWebView resolves relative links against baseURL before
        // they reach the navigation delegate, so most URLs arrive absolute.
        if url.scheme == "file" && url.path.hasPrefix("/") {
            return url.standardizedFileURL
        }
        // For genuinely relative URLs (no scheme or relative path),
        // resolve against baseDirectory if available.
        if let base = baseDirectory {
            return base.appendingPathComponent(url.path).standardizedFileURL
        }
        return url.standardizedFileURL
    }

    func isMarkdownFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["md", "markdown", "mdown", "mkd"].contains(ext)
    }

    func isWithinBaseDirectory(_ url: URL) -> Bool {
        guard let base = baseDirectory else { return false }
        let basePath = base.resolvingSymlinksInPath().path
        let targetPath = url.resolvingSymlinksInPath().path
        // Defensive: require trailing separator on base to avoid prefix spoofing
        // (e.g. /foo/bar matching /foo/barbaz). Handle root directory edge case.
        let prefix = basePath == "/" ? "/" : basePath + "/"
        return targetPath.hasPrefix(prefix) || targetPath == basePath
    }
}

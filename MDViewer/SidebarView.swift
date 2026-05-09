import SwiftUI

struct SidebarView: View {
    @ObservedObject var documentState: DocumentState
    @Binding var isVisible: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            listContent
        }
        .frame(width: 220)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var header: some View {
        HStack {
            Text(directoryName)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Button(action: { isVisible = false }) {
                Image(systemName: "sidebar.left")
            }
            .buttonStyle(.plain)
            .help("Hide Sidebar")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var listContent: some View {
        Group {
            if documentState.currentURL == nil {
                emptyState(message: "Open a Markdown file to browse its directory.")
            } else if siblingFiles.isEmpty {
                if enumerationFailed {
                    emptyState(message: "Unable to read directory.")
                } else {
                    emptyState(message: "No Markdown files in this folder.")
                }
            } else {
                List(selection: Binding(
                    get: { documentState.currentURL },
                    set: { newURL in
                        if let url = newURL {
                            documentState.load(url: url)
                        }
                    }
                )) {
                    ForEach(siblingFiles, id: \.self) { url in
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(url.lastPathComponent)
                            .tag(url)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func emptyState(message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            Spacer()
        }
    }

    private var directoryName: String {
        guard let url = documentState.currentURL else { return "Files" }
        return url.deletingLastPathComponent().lastPathComponent
    }

    private var enumerationFailed: Bool {
        guard let url = documentState.currentURL else { return false }
        let dir = url.deletingLastPathComponent()
        do {
            _ = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            return false
        } catch {
            return true
        }
    }

    private var siblingFiles: [URL] {
        guard let url = documentState.currentURL else { return [] }
        let dir = url.deletingLastPathComponent()
        let mdExtensions = Set(["md", "markdown", "mdown", "mkd"])

        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            return []
        }

        let mdFiles = files.filter { mdExtensions.contains($0.pathExtension.lowercased()) }

        // Pre-fetch dates in a single pass for performance
        var datedFiles: [(url: URL, date: Date)] = []
        for file in mdFiles {
            let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            datedFiles.append((file, date))
        }

        switch documentState.sortOrder {
        case .alphabetical:
            return datedFiles
                .sorted { $0.url.lastPathComponent.lowercased() < $1.url.lastPathComponent.lowercased() }
                .map { $0.url }
        case .dateModified:
            return datedFiles
                .sorted { $0.date > $1.date }
                .map { $0.url }
        }
    }
}

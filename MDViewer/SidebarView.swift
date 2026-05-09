import SwiftUI

struct SidebarView: View {
    @ObservedObject var documentState: DocumentState
    @Binding var isVisible: Bool
    @State private var expandedFiles: Set<URL> = []
    @State private var headerCache: [URL: [HeaderNode]] = [:]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            listContent
        }
        .frame(width: 220)
        .background(Color(nsColor: .controlBackgroundColor))
        .onChange(of: documentState.currentURL) { newURL in
            if let url = newURL {
                expandedFiles.insert(url)
            }
        }
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
                List {
                    ForEach(rowItems, id: \.id) { item in
                        rowView(for: item)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Row Types

    private enum RowItem: Identifiable {
        case file(url: URL, isExpanded: Bool, isCurrent: Bool)
        case h1(text: String, anchorID: String, fileURL: URL)
        case h2(text: String, anchorID: String, fileURL: URL)

        var id: String {
            switch self {
            case .file(let url, _, _):
                return "file:\(url.path)"
            case .h1(let text, _, let fileURL):
                return "h1:\(fileURL.path)#\(text)"
            case .h2(let text, _, let fileURL):
                return "h2:\(fileURL.path)#\(text)"
            }
        }
    }

    private var rowItems: [RowItem] {
        var rows: [RowItem] = []
        for url in siblingFiles {
            let isCurrent = url == documentState.currentURL
            let isExpanded = expandedFiles.contains(url)
            rows.append(.file(url: url, isExpanded: isExpanded, isCurrent: isCurrent))
            if isExpanded {
                let nodes = headersForFile(url)
                for node in nodes {
                    rows.append(.h1(text: node.text, anchorID: node.id, fileURL: url))
                    for h2 in node.h2s {
                        rows.append(.h2(text: h2.text, anchorID: h2.id, fileURL: url))
                    }
                }
            }
        }
        return rows
    }

    private func rowView(for item: RowItem) -> some View {
        switch item {
        case .file(let url, let isExpanded, let isCurrent):
            return AnyView(fileRow(url: url, isExpanded: isExpanded, isCurrent: isCurrent))
        case .h1(let text, let anchorID, let fileURL):
            return AnyView(h1Row(text: text, anchorID: anchorID, fileURL: fileURL))
        case .h2(let text, let anchorID, let fileURL):
            return AnyView(h2Row(text: text, anchorID: anchorID, fileURL: fileURL))
        }
    }

    // MARK: - File Row

    private func fileRow(url: URL, isExpanded: Bool, isCurrent: Bool) -> some View {
        HStack(spacing: 4) {
            Button(action: { toggleExpanded(url) }) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Button(action: { documentState.load(url: url) }) {
                Text(url.lastPathComponent)
                    .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(isCurrent ? .accentColor : .primary)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.leading, 4)
        .padding(.vertical, 2)
        .background(isCurrent ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }

    // MARK: - Header Row

    private func h1Row(text: String, anchorID: String, fileURL: URL) -> some View {
        Button(action: {
            NSLog("[Sidebar] H1 tapped: text='%@' anchor='%@' file='%@' current='%@'", text, anchorID, fileURL.lastPathComponent, documentState.currentURL?.lastPathComponent ?? "nil")
            if fileURL == documentState.currentURL {
                documentState.scrollToAnchor(anchorID)
            } else {
                documentState.load(url: fileURL, scrollToAnchor: anchorID)
            }
        }) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1)
                    .padding(.leading, 12)

                Text(text)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
                    .padding(.vertical, 1)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func h2Row(text: String, anchorID: String, fileURL: URL) -> some View {
        Button(action: {
            NSLog("[Sidebar] H2 tapped: text='%@' anchor='%@' file='%@' current='%@'", text, anchorID, fileURL.lastPathComponent, documentState.currentURL?.lastPathComponent ?? "nil")
            if fileURL == documentState.currentURL {
                documentState.scrollToAnchor(anchorID)
            } else {
                documentState.load(url: fileURL, scrollToAnchor: anchorID)
            }
        }) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 12)

                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 1)
                    .padding(.leading, 4)

                Text(text)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(.secondary.opacity(0.8))
                    .padding(.leading, 8)
                    .padding(.vertical, 1)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func toggleExpanded(_ url: URL) {
        if expandedFiles.contains(url) {
            expandedFiles.remove(url)
        } else {
            expandedFiles.insert(url)
            // Lazy-parse headers for non-current files
            if url != documentState.currentURL && headerCache[url] == nil {
                headerCache[url] = DocumentState.parseHeaders(from: url)
            }
        }
    }

    private func headersForFile(_ url: URL) -> [HeaderNode] {
        if url == documentState.currentURL {
            return documentState.currentFileHeaders
        }
        return headerCache[url] ?? []
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

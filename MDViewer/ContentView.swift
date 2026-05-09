import SwiftUI

struct ContentView: View {
    let document: MarkdownDocument
    let fileURL: URL?
    let appearanceMode: AppearanceMode
    let zoomLevel: Double
    let lightThemeID: String
    let darkThemeID: String
    let fitDiagramsToView: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var text: String
    @StateObject private var documentState = DocumentState()
    @State private var filePickerState: FilePickerState? = nil

    init(document: MarkdownDocument, fileURL: URL?, appearanceMode: AppearanceMode, zoomLevel: Double, lightThemeID: String, darkThemeID: String, fitDiagramsToView: Bool) {
        self.document = document
        self.fileURL = fileURL
        self.appearanceMode = appearanceMode
        self.zoomLevel = zoomLevel
        self.lightThemeID = lightThemeID
        self.darkThemeID = darkThemeID
        self.fitDiagramsToView = fitDiagramsToView
        self._text = State(initialValue: document.text)
    }

    private var theme: Theme {
        let lightTheme = Theme.theme(for: lightThemeID, in: Theme.themes)
        let darkTheme = Theme.theme(for: darkThemeID, in: Theme.themes)
        switch appearanceMode {
        case .light:
            return lightTheme
        case .dark:
            return darkTheme
        case .system:
            return colorScheme == .dark ? darkTheme : lightTheme
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            if documentState.showSidebar {
                SidebarView(documentState: documentState, isVisible: $documentState.showSidebar)
                    .transition(reduceMotion ? .identity : .move(edge: .leading))
            }

            ZStack(alignment: .bottom) {
                MarkdownWebView(
                    text: text,
                    zoomLevel: zoomLevel,
                    theme: theme,
                    baseDirectory: documentState.currentURL?.deletingLastPathComponent()
                        ?? fileURL?.deletingLastPathComponent(),
                    fitDiagramsToView: fitDiagramsToView
                )
                .environmentObject(documentState)

                if documentState.showFindBar {
                    FindBarView(documentState: documentState)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if let state = filePickerState {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { documentState.showFilePicker = false }
                    FilePickerView(state: state)
                        .transition(reduceMotion ? .identity : .opacity)
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: documentState.showSidebar)
        .animation(.easeInOut(duration: 0.15), value: documentState.showFindBar)
        .animation(.easeInOut(duration: 0.15), value: documentState.showFilePicker)
        .focusedSceneValue(\.documentState, documentState)
        .navigationTitle(documentState.currentURL?.lastPathComponent ?? fileURL?.lastPathComponent ?? "")
        .onAppear {
            if let url = fileURL {
                documentState.load(url: url)
            }
            // Sync sidebar visibility from the global preference.
            documentState.showSidebar = UserDefaults.standard.bool(forKey: "showSidebar")
        }
        .onChange(of: documentState.currentURL, perform: { _ in
            text = documentState.renderedText
            // DocumentGroup manages the window title via the document; since we navigate
            // by loading content into the existing document state, we must manually sync
            // the title bar and proxy icon to reflect the new file.
            if let url = documentState.currentURL {
                NSApp.keyWindow?.title = url.lastPathComponent
                NSApp.keyWindow?.representedURL = url
            }
        })
        .onChange(of: documentState.showSidebar) { newValue in
            // Persist per-document toggle so it becomes the new default.
            UserDefaults.standard.set(newValue, forKey: "showSidebar")
        }
        .onReceive(NotificationCenter.default.publisher(for: .sidebarPreferenceChanged)) { _ in
            // Live-sync when the user changes the preference in the Settings panel.
            documentState.showSidebar = UserDefaults.standard.bool(forKey: "showSidebar")
        }
        .onReceive(NotificationCenter.default.publisher(for: .reloadDocument)) { _ in
            reload()
        }
        .onChange(of: documentState.showFilePicker, perform: { isShowing in
            if isShowing {
                filePickerState = FilePickerState(
                    anchorDirectory: documentState.currentURL?.deletingLastPathComponent()
                        ?? FileManager.default.homeDirectoryForCurrentUser,
                    onCommit: { [weak documentState] url in
                        documentState?.showFilePicker = false
                        // TODO(sandbox): needs security-scoped bookmark if App Sandbox entitlement is ever added
                        NSDocumentController.shared.openDocument(
                            withContentsOf: url,
                            display: true
                        ) { _, _, error in
                            if let error {
                                DispatchQueue.main.async { NSApplication.shared.presentError(error) }
                            }
                        }
                    },
                    onDismiss: { [weak documentState] in
                        documentState?.showFilePicker = false
                    }
                )
            } else {
                filePickerState = nil
                if let wv = documentState.webView {
                    NSApp.keyWindow?.makeFirstResponder(wv)
                }
            }
        })
    }

    private func reload() {
        let url = documentState.currentURL ?? fileURL
        guard let url,
              let newText = try? String(contentsOf: url, encoding: .utf8)
        else { return }
        text = newText
    }
}

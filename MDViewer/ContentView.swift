import SwiftUI

struct ContentView: View {
    let document: MarkdownDocument
    let fileURL: URL?
    let appearanceMode: AppearanceMode
    let zoomLevel: Double
    let lightThemeID: String
    let darkThemeID: String
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var text: String
    @StateObject private var documentState = DocumentState()
    @State private var filePickerState: FilePickerState? = nil

    init(document: MarkdownDocument, fileURL: URL?, appearanceMode: AppearanceMode, zoomLevel: Double, lightThemeID: String, darkThemeID: String) {
        self.document = document
        self.fileURL = fileURL
        self.appearanceMode = appearanceMode
        self.zoomLevel = zoomLevel
        self.lightThemeID = lightThemeID
        self.darkThemeID = darkThemeID
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
        ZStack(alignment: .bottom) {
            MarkdownWebView(text: text, zoomLevel: zoomLevel, theme: theme)
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
        .animation(.easeInOut(duration: 0.15), value: documentState.showFindBar)
        .animation(.easeInOut(duration: 0.15), value: documentState.showFilePicker)
        .focusedSceneValue(\.documentState, documentState)
        .navigationTitle(documentState.currentURL?.lastPathComponent ?? fileURL?.lastPathComponent ?? "")
        .onAppear {
            if let url = fileURL {
                documentState.load(url: url)
            }
        }
        .onChange(of: documentState.currentURL, perform: { _ in
            text = documentState.renderedText
        })
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

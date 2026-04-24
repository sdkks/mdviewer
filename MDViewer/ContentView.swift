import SwiftUI

struct ContentView: View {
    let document: MarkdownDocument
    let fileURL: URL?
    let appearanceMode: AppearanceMode
    let zoomLevel: Double
    let lightThemeID: String
    let darkThemeID: String
    @Environment(\.colorScheme) private var colorScheme
    @State private var text: String
    @StateObject private var documentState = DocumentState()

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
        }
        .animation(.easeInOut(duration: 0.15), value: documentState.showFindBar)
        .focusedSceneValue(\.documentState, documentState)
        .navigationTitle(documentState.currentURL?.lastPathComponent ?? fileURL?.lastPathComponent ?? "")
        .onAppear {
            if let url = fileURL {
                documentState.load(url: url)
            }
        }
        .onChange(of: documentState.currentURL) { _ in
            text = documentState.renderedText
        }
        .onReceive(NotificationCenter.default.publisher(for: .reloadDocument)) { _ in
            reload()
        }
    }

    private func reload() {
        let url = documentState.currentURL ?? fileURL
        guard let url,
              let newText = try? String(contentsOf: url, encoding: .utf8)
        else { return }
        text = newText
    }
}

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
        MarkdownWebView(text: text, zoomLevel: zoomLevel, theme: theme)
            .onReceive(NotificationCenter.default.publisher(for: .reloadDocument)) { _ in
                reload()
            }
    }

    private func reload() {
        guard let url = fileURL,
              let newText = try? String(contentsOf: url, encoding: .utf8)
        else { return }
        text = newText
    }
}

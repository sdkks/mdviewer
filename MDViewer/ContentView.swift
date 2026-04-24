import SwiftUI

struct ContentView: View {
    let document: MarkdownDocument
    let fileURL: URL?
    let appearanceMode: AppearanceMode
    let zoomLevel: Double
    let theme: Theme
    @State private var text: String

    init(document: MarkdownDocument, fileURL: URL?, appearanceMode: AppearanceMode, zoomLevel: Double, theme: Theme) {
        self.document = document
        self.fileURL = fileURL
        self.appearanceMode = appearanceMode
        self.zoomLevel = zoomLevel
        self._text = State(initialValue: document.text)
		self.theme = theme
    }

    var body: some View {
        MarkdownWebView(
            text: text,
            zoomLevel: zoomLevel,
			theme: theme
        )
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

import SwiftUI

struct Theme: Identifiable {
    let id: String
    let name: String
    let colors: ThemeColors
}

struct ThemeColors {
    let bg: String
    let fg: String
    let border: String
    let codeBg: String
    let link: String
    let blockquoteFg: String
    let blockquoteBorder: String
    let hr: String

    func cssVariables() -> String {
        return """
        --color-bg: \(bg);
        --color-fg: \(fg);
        --color-border: \(border);
        --color-code-bg: \(codeBg);
        --color-link: \(link);
        --color-blockquote-fg: \(blockquoteFg);
        --color-blockquote-border: \(blockquoteBorder);
        --color-hr: \(hr);
        """
    }
}

extension Theme {
    static let themes: [Theme] = [
        Theme(
            id: "github-light",
            name: "GitHub Light",
            colors: ThemeColors(
                bg: "#ffffff",
                fg: "#24292f",
                border: "#d0d7de",
                codeBg: "#f6f8fa",
                link: "#0969da",
                blockquoteFg: "#656d76",
                blockquoteBorder: "#d0d7de",
                hr: "#d8dee4"
            )
        ),
        Theme(
            id: "solarized-light",
            name: "Solarized Light",
            colors: ThemeColors(
                bg: "#fdf6e3",
                fg: "#657b83",
                border: "#93a1a1",
                codeBg: "#eee8d5",
                link: "#268bd2",
                blockquoteFg: "#586e75",
                blockquoteBorder: "#93a1a1",
                hr: "#93a1a1"
            )
        ),
        Theme(
            id: "github-dark",
            name: "GitHub Dark",
            colors: ThemeColors(
                bg: "#0d1117",
                fg: "#e6edf3",
                border: "#30363d",
                codeBg: "#161b22",
                link: "#58a6ff",
                blockquoteFg: "#8b949e",
                blockquoteBorder: "#30363d",
                hr: "#21262d"
            )
        ),
        Theme(
            id: "dracula",
            name: "Dracula",
            colors: ThemeColors(
                bg: "#282a36",
                fg: "#f8f8f2",
                border: "#44475a",
                codeBg: "#44475a",
                link: "#bd93f9",
                blockquoteFg: "#6272a4",
                blockquoteBorder: "#44475a",
                hr: "#44475a"
            )
        ),
        Theme(
            id: "solarized-dark",
            name: "Solarized Dark",
            colors: ThemeColors(
                bg: "#002b36",
                fg: "#839496",
                border: "#073642",
                codeBg: "#073642",
                link: "#268bd2",
                blockquoteFg: "#586e75",
                blockquoteBorder: "#073642",
                hr: "#073642"
            )
        ),
        Theme(
            id: "monokai",
            name: "Monokai",
            colors: ThemeColors(
                bg: "#272822",
                fg: "#f8f8f2",
                border: "#49483e",
                codeBg: "#3e3d32",
                link: "#66d9ef",
                blockquoteFg: "#75715e",
                blockquoteBorder: "#49483e",
                hr: "#49483e"
            )
        ),
        Theme(
            id: "nord",
            name: "Nord",
            colors: ThemeColors(
                bg: "#2e3440",
                fg: "#eceff4",
                border: "#4c566a",
                codeBg: "#3b4252",
                link: "#88c0d0",
                blockquoteFg: "#d8dee9",
                blockquoteBorder: "#4c566a",
                hr: "#4c566a"
            )
        )
    ]

    static func theme(for id: String, in themes: [Theme]) -> Theme {
        themes.first { $0.id == id } ?? themes[0]
    }
}

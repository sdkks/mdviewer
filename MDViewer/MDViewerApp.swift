import SwiftUI

extension Notification.Name {
    static let reloadDocument = Notification.Name("reloadDocument")
}

enum AppearanceMode: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

@main
struct MDViewerApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @AppStorage("zoomLevel") private var zoomLevel: Double = 1.0
    @AppStorage("lightThemeID") private var lightThemeID: String = "github-light"
    @AppStorage("darkThemeID") private var darkThemeID: String = "github-dark"
	
	private func selectTheme() -> Theme {
		let lightTheme = Theme.theme(for: lightThemeID, in: Theme.themes)
		let darkTheme = Theme.theme(for: darkThemeID, in: Theme.themes)
		switch AppearanceMode(rawValue: appearanceMode) {
		case .light:
			return lightTheme
		case .dark:
			return darkTheme
		default:
			let isDark = NSApp.effectiveAppearance.name == .darkAqua
			return isDark ? darkTheme : lightTheme
		}
	}

    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            ContentView(
                document: file.document,
                fileURL: file.fileURL,
                appearanceMode: AppearanceMode(rawValue: appearanceMode) ?? .system,
                zoomLevel: zoomLevel,
                theme: selectTheme(),
            )
        }
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Reload") {
                    NotificationCenter.default.post(name: .reloadDocument, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Zoom In") {
                    zoomLevel = min(zoomLevel + 0.1, 3.0)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    zoomLevel = max(zoomLevel - 0.1, 0.5)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Actual Size") {
                    zoomLevel = 1.0
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()
                Menu("Appearance") {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Button {
                            appearanceMode = mode.rawValue
                        } label: {
                            if appearanceMode == mode.rawValue {
                                Text("\(mode.label)")
                            } else {
                                Text(mode.label)
                            }
                        }
                        .keyboardShortcut(shortcut(for: mode))
                    }
                }
            }
        }
		
		Settings {
			PreferencesView(
				lightThemeID: $lightThemeID,
				darkThemeID: $darkThemeID
			)
		}
		.restorationBehavior(.disabled)
    }

    private func shortcut(for mode: AppearanceMode) -> KeyboardShortcut {
        switch mode {
        case .system: return KeyboardShortcut("0", modifiers: [.command, .shift])
        case .light: return KeyboardShortcut("1", modifiers: [.command, .shift])
        case .dark: return KeyboardShortcut("2", modifiers: [.command, .shift])
        }
    }
}

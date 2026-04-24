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

struct MDViewerCommands: Commands {
    @FocusedValue(\.documentState) private var documentState: DocumentState?

    var body: some Commands {
        CommandMenu("Navigate") {
            Button("Previous File") {
                documentState?.navigatePrevious()
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)
            .disabled(documentState == nil)

            Button("Next File") {
                documentState?.navigateNext()
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)
            .disabled(documentState == nil)
        }

        CommandMenu("Sort By") {
            ForEach(FileSortOrder.allCases, id: \.self) { order in
                Button(order == .alphabetical ? "Alphabetical" : "Date Modified") {
                    documentState?.sortOrder = order
                }
                .disabled(documentState == nil)
            }
        }

        CommandGroup(after: .textEditing) {
            Menu("Find") {
                Button("Find\u{2026}") {
                    documentState?.activateFind()
                }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(documentState == nil)

                Button("Find Next") {
                    documentState?.findNext()
                }
                .keyboardShortcut("g", modifiers: .command)
                .disabled(documentState == nil)

                Button("Find Previous") {
                    documentState?.findPrevious()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(documentState == nil)

                Divider()
                Button("Open File\u{2026}") {
                    documentState?.activateFilePicker()
                }
                .keyboardShortcut("k", modifiers: .command)
                .disabled(documentState == nil)
            }
        }
    }
}

@main
struct MDViewerApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @AppStorage("zoomLevel") private var zoomLevel: Double = 1.0
    @AppStorage("lightThemeID") private var lightThemeID: String = "github-light"
    @AppStorage("darkThemeID") private var darkThemeID: String = "github-dark"

    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            ContentView(
                document: file.document,
                fileURL: file.fileURL,
                appearanceMode: AppearanceMode(rawValue: appearanceMode) ?? .system,
                zoomLevel: zoomLevel,
                lightThemeID: lightThemeID,
                darkThemeID: darkThemeID
            )
        }
        .commands {
            MDViewerCommands()
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
    }

    private func shortcut(for mode: AppearanceMode) -> KeyboardShortcut {
        switch mode {
        case .system: return KeyboardShortcut("0", modifiers: [.command, .shift])
        case .light: return KeyboardShortcut("1", modifiers: [.command, .shift])
        case .dark: return KeyboardShortcut("2", modifiers: [.command, .shift])
        }
    }
}

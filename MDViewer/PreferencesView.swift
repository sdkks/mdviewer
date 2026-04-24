import SwiftUI

struct PreferencesView: View {
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @AppStorage("zoomLevel") private var zoomLevel: Double = 1.0
    @Binding var lightThemeID: String
    @Binding var darkThemeID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Section {
                Picker("Appearance", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Picker("Light Theme", selection: $lightThemeID) {
                    ForEach(Theme.themes) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }
            }

            Section {
                Picker("Dark Theme", selection: $darkThemeID) {
                    ForEach(Theme.themes) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }
            }

            Section {
                HStack(alignment: .center, spacing: 10) {
                    Text("Zoom")
                    Slider(
                        value: $zoomLevel,
                        in: 0.25...1.75,
                        step: 0.15
                    )
                    Text(String(format: "%.0f", zoomLevel * 100) + "%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    appearanceMode = AppearanceMode.system.rawValue
                    lightThemeID = "github-light"
                    darkThemeID = "github-dark"
                    zoomLevel = 1.0
                }
            }
        }
		.onChange(of: appearanceMode) { _, newValue in
			updateAppAppearance(newValue)
		}
        .padding(20)
        .frame(width: 300)
    }
	
	private func updateAppAppearance(_ mode: String) {
		let appMode = AppearanceMode(rawValue: mode) ?? .system
		switch appMode {
			case .system:
				NSApp.appearance = nil
			case .light:
				NSApp.appearance = NSAppearance(named: .aqua)
			case .dark:
				NSApp.appearance = NSAppearance(named: .darkAqua)
		}
	}
}

#Preview {
    PreferencesView(lightThemeID: .constant("github-light"), darkThemeID: .constant("github-dark"))
}

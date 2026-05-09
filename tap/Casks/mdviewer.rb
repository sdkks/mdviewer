cask "mdviewer" do
  version "2.5.0"
  sha256 "61a5947db13eabfc1437cd92e6394d5a7e88bda5ba8685a9861eb68af2c87ec3"

  url "https://github.com/sdkks/mdviewer/releases/download/v#{version}/MDViewer-#{version}.zip"
  name "MDViewer"
  desc "Minimal native macOS Markdown viewer"
  homepage "https://github.com/sdkks/mdviewer"

  app "MDViewer.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/MDViewer.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Preferences/com.torstenmahr.MDViewer.plist",
    "~/Library/Application Support/MDViewer",
  ]
end

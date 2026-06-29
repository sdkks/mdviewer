cask "mdviewer" do
  version "2.7.1"
  sha256 "40855b75228240a690fcce29a155d855f0f071f5daf2051288c310902cde199d"

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

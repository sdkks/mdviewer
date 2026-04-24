.PHONY: build release version-bump

build:
	xcodegen generate
	xcodebuild -scheme MDViewer -configuration Release build

# Developer-machine-only target.
# Prerequisites: Xcode + Command Line Tools, gh CLI (brew install gh), gh auth login
# The current git HEAD must be tagged (run make version-bump first).
# Produces: MDViewer-<VERSION>.zip attached to GitHub Release for the current git tag.
# Note: build is unsigned/unnotarized — users may need right-click > Open on first launch (Gatekeeper).
# Signing is the developer's responsibility.
release:
	@which gh > /dev/null 2>&1 || { echo "gh CLI not found. Install via: brew install gh"; exit 1; }
	$(eval VERSION := $(shell grep 'MARKETING_VERSION' project.yml | head -1 | sed 's/.*: *//;s/"//g;s/ //g'))
	$(eval TAG := $(shell git describe --tags --exact-match 2>/dev/null || echo ""))
	@test -n "$(TAG)" || { echo "No git tag on HEAD — run make version-bump or create a tag first"; exit 1; }
	git push && git push --tags
	xcodebuild archive \
		-project MDViewer.xcodeproj \
		-scheme MDViewer \
		-configuration Release \
		-archivePath build/MDViewer.xcarchive \
		CODE_SIGNING_ALLOWED=NO
	xcodebuild -exportArchive \
		-archivePath build/MDViewer.xcarchive \
		-exportOptionsPlist ExportOptions.plist \
		-exportPath build/export \
		CODE_SIGNING_ALLOWED=NO
	ditto -c -k --keepParent "build/export/MDViewer.app" "build/MDViewer-$(VERSION).zip"
	gh release create $(TAG) --title "MDViewer $(VERSION)" --notes "" || true
	gh release upload $(TAG) "build/MDViewer-$(VERSION).zip" --clobber
	@echo "Released MDViewer $(VERSION) as $(TAG)"

version-bump:
	@bash scripts/version-bump.sh

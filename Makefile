.PHONY: build

build:
	xcodegen generate
	xcodebuild -scheme MDViewer -configuration Release build

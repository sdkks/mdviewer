# MDViewer

A minimal macOS Markdown viewer. No editor, no bloat — just clean rendering with automatic Dark Mode support.

![macOS](https://img.shields.io/badge/macOS-13.0+-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue)
![Size](https://img.shields.io/badge/App_Size-~4MB-2ea44f)
![Memory](https://img.shields.io/badge/Memory-<100MB-2ea44f)

## Features

- **GitHub-flavored rendering** via [marked.js](https://marked.js.org)
- **Mermaid diagrams** — fenced ` ```mermaid ` blocks render natively as SVG
- **Dark Mode** — automatic (system), light, or dark via View > Appearance
- **Zoom** — `Cmd +` / `Cmd -` with persistent zoom level
- **Reload** — `Cmd R` to refresh after external edits
- **File navigation** — `Cmd ←` / `Cmd →` cycles through all `.md` files in the same directory, alphabetically (or by date modified — change in Sort By menu)
- **In-document search** — `Cmd F` find bar with next/previous match and match count
- **Quick open** — `Cmd K` floating file picker: type a path, Tab to complete directories, `../` to navigate up, results filtered to `.md` files only
- **Native file handling** — Open, Recent Files, drag & drop
- **No Electron, no runtime** — native macOS app

![MD Viewer V2 DEMO GIF](./docs/mdviewer-v2-demo.gif)

## Performance

| Metric         | Value   |
| -------------- | ------- |
| App size       | ~ 4 MB  |
| Download (zip) | ~ 1 MB  |
| Cold start     | < 50 ms |
| Memory         | < 100 MB |

## Install

### Homebrew (recommended)

```bash
brew tap sdkks/tap
brew install --cask mdviewer
```

Gatekeeper is handled automatically — no extra steps needed.

### Manual

Download the latest `.app` from [Releases](https://github.com/sdkks/mdviewer/releases), unzip, and drag to `/Applications`.

On first launch macOS will block the app because it is unsigned. Right-click > Open works, or run this once in Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/MDViewer.app
```

## Keyboard Shortcuts

| Action                     | Shortcut      |
| -------------------------- | ------------- |
| Previous file in directory | `Cmd ←`       |
| Next file in directory     | `Cmd →`       |
| Find in document           | `Cmd F`       |
| Find next match            | `Cmd G`       |
| Find previous match        | `Cmd Shift G` |
| Quick open file            | `Cmd K`       |
| Reload                     | `Cmd R`       |
| Zoom In                    | `Cmd +`       |
| Zoom Out                   | `Cmd -`       |
| Actual Size                | `Cmd 0`       |
| System Appearance          | `Cmd Shift 0` |
| Light Mode                 | `Cmd Shift 1` |
| Dark Mode                  | `Cmd Shift 2` |

## Quick Open (Cmd K)

The file picker lets you jump to any `.md` file on your filesystem without leaving the keyboard:

- Type a partial path or filename — results update as you type (substring match)
- **Tab** — completes the current directory segment; appends `/` to drill in
- **`../`** — navigates to the parent directory, just like a shell
- **`../../`** — chains upward arbitrarily
- **↑ / ↓** — move through the candidate list
- **Return** — opens the selected file in a new window
- **Escape** — closes the picker without navigating

The picker anchors to the directory of the currently open file, or your home directory if no file is open.

## Building from Source

**Prerequisites:** Xcode 16+, Command Line Tools, [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```bash
brew install xcodegen
git clone https://github.com/sdkks/mdviewer
cd mdviewer
make build
```

`make build` runs `xcodegen generate` then builds a Release `.app` in Xcode's DerivedData.

## Releasing

### 1. Make a commit with a versioned prefix

The version bump script reads the most recent commit message to decide which component to increment:

| Commit prefix | Version bump          |
| ------------- | --------------------- |
| `Breaking:`   | major (1.0.0 → 2.0.0) |
| `Feature:`    | minor (1.0.0 → 1.1.0) |
| `Core:`       | minor (1.0.0 → 1.1.0) |
| `Fix:`        | patch (1.0.0 → 1.0.1) |

Example:

```bash
git commit -m "Feature: add table of contents sidebar"
```

### 2. Bump the version

```bash
make version-bump
```

This reads the last commit message, increments `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`, regenerates the Xcode project, commits the change, and creates an annotated git tag (e.g. `v1.1.0`).

### 3. Ship it

**Prerequisites:** [`gh` CLI](https://cli.github.com) installed and authenticated, `GH_TOKEN` env var set with a fine-grained token scoped to `sdkks/mdviewer` with **Contents: read & write**.

```bash
make release
```

This pushes all commits and tags, builds a Release archive, ad-hoc signs `MDViewer.app`, zips it, creates a GitHub Release for the current tag, uploads the zip as a release asset, and updates the Homebrew cask in [`sdkks/homebrew-tap`](https://github.com/sdkks/homebrew-tap) automatically.

**Prerequisites for tap push:** the tap repo must be checked out at `../tap` relative to this repo.

## Dependencies

| Library                                          | Version | License | Purpose                      |
| ------------------------------------------------ | ------- | ------- | ---------------------------- |
| [marked](https://github.com/markedjs/marked)     | 15.0.7  | MIT     | Markdown → HTML parsing      |
| [mermaid](https://github.com/mermaid-js/mermaid) | 11      | MIT     | Diagram rendering (SVG)      |

No Swift package dependencies. No external frameworks.

## License

[MIT](LICENSE)

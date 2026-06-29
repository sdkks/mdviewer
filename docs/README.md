# MDViewer Documentation

This directory contains example Markdown files for testing MDViewer features.

## Files

| File | Purpose |
|------|---------|
| [examples/all-features.md](examples/all-features.md) | Comprehensive demo of every v2.5.0 feature |
| [examples/architecture.md](examples/architecture.md) | Architecture notes with code diagrams |
| [examples/getting-started.md](examples/getting-started.md) | User onboarding guide |
| [frontmatter-smoke-matrix.md](frontmatter-smoke-matrix.md) | Manual fixture matrix for YAML frontmatter support and renderer regressions |

## Quick Test Checklist

Open `examples/all-features.md` and verify:

1. **Sidebar** shows these three `.md` files
2. **Syntax highlighting** colors Swift/JS/Python/JSON blocks
3. **Mermaid diagrams** render with zoom/pan working
4. **Error diagnostics** appear on the invalid diagram block
5. **Footnotes** render at bottom with back-links
6. **Internal links** open sibling files on Cmd+Click
7. **Export** menu is enabled (3 diagrams detected)
8. **Frontmatter fixtures** in `frontmatter-smoke-matrix.md` cover valid, invalid, security, CRLF/BOM, and regression cases

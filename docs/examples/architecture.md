# Architecture Overview

This document describes the MDViewer architecture for contributors and curious users.

## High-Level Stack

```
┌─────────────────────────────────────┐
│  SwiftUI (ContentView, SidebarView) │
├─────────────────────────────────────┤
│  NSViewRepresentable (MarkdownWebView)
├─────────────────────────────────────┤
│  WKWebView                          │
│  ├── marked.js   (Markdown → HTML)  │
│  ├── mermaid.js  (Diagram rendering)│
│  ├── highlight.js (Syntax coloring) │
│  ├── marked-footnote (Footnotes)    │
│  └── svg-pan-zoom (Diagram zoom)    │
├─────────────────────────────────────┤
│  template.html (Injected content)   │
└─────────────────────────────────────┘
```

## Security Model

- All Markdown content is escaped before injection (`<` → `\u003C`)
- `file://` links are validated against base directory containment
- Path traversal (`../../../etc/passwd`) is blocked via `resolvingSymlinksInPath()`

## Related

- [All Features Demo](all-features.md)
- [Getting Started](getting-started.md)

# Frontmatter Smoke Matrix

This matrix is the repeatable manual fixture corpus for GitHub-style YAML frontmatter rendering in MDViewer (SPEC-0001 / TASK-0001). Open each fixture in `docs/examples/frontmatter-fixtures/` with MDViewer and compare the visible result with the expected behavior below.

## How to run

1. Build and launch MDViewer.
2. Open each `.md` file in `docs/examples/frontmatter-fixtures/`.
3. Verify the expected behavior in the matrix. Cases marked **Feature** validate frontmatter support; cases marked **Regression** validate that existing Markdown rendering still works after frontmatter preprocessing.
4. For security-sensitive fixtures, verify literal text is displayed and no HTML/script executes.

## Expected frontmatter contract

- Frontmatter is detected only at the very beginning of the document, except an optional UTF-8 BOM may precede `---`.
- Opening and closing delimiter lines must be exactly `---`.
- Valid metadata renders as a compact metadata card before the Markdown body and raw delimiters are not shown.
- Empty frontmatter renders the Markdown body normally with no metadata card.
- Scalar and array root frontmatter render under a generic `value` row.
- Malformed frontmatter renders a visible parse-error card, preserves escaped raw frontmatter, and still renders the body.
- YAML-derived keys and values display as escaped text, not executable HTML or Markdown.

## Matrix

| ID | Fixture | Type | Coverage | Expected visible behavior |
|---:|---|---|---|---|
| 01 | `01-no-frontmatter.md` | Regression | No frontmatter | Renders like normal Markdown. No metadata card or parse-error card appears. |
| 02 | `02-valid-object.md` | Feature | Valid object with string, boolean, array | Metadata card contains `title`, `published`, and `tags`; body heading renders below; raw delimiters are absent. |
| 03 | `03-nested.md` | Feature | Nested object/array metadata | Metadata card shows nested `author`, `reviewers`, and `release` values readably; body renders below. |
| 04 | `04-empty.md` | Feature | Empty frontmatter | No metadata rows/card required; body heading renders; raw delimiters are absent. |
| 05 | `05-root-scalar.md` | Feature | Root scalar YAML | Metadata card shows one generic `value` row containing the scalar; body renders below. |
| 06 | `06-root-array.md` | Feature | Root array YAML | Metadata card shows one generic `value` row with array items; body renders below. |
| 07 | `07-malformed-yaml.md` | Feature | Malformed YAML | Visible frontmatter parse-error card appears, original raw block is shown escaped, and body renders below. |
| 08 | `08-missing-close-delimiter.md` | Regression | Leading delimiter with no closing delimiter | Treated as ordinary Markdown/thematic break input; no frontmatter stripping or parse-error card. |
| 09 | `09-body-delimiter.md` | Regression | Delimiter later in body | Later `---` remains a body thematic break or text according to Marked; no metadata card. |
| 10 | `10-crlf.md` | Feature | CRLF-authored document | Metadata card is detected and rendered despite CRLF line endings; body renders below. |
| 11 | `11-bom.md` | Feature | UTF-8 BOM before opening delimiter | Metadata card is detected and rendered; no visible BOM character or raw delimiters. |
| 12 | `12-html-script-like-value.md` | Security | HTML/script-like YAML value | Literal `<script>alert('frontmatter')</script>` text is visible in metadata; no alert runs and no HTML is interpreted. |
| 13 | `13-long-values.md` | Feature | Very long key/value and long URL | Metadata wraps without horizontal page overflow; body remains readable. |
| 14 | `14-deep-nesting.md` | Feature | Deep nesting beyond render depth | Nested metadata remains legible; depth beyond renderer limit falls back safely (for example escaped JSON/preformatted text) without layout breakage. |
| 15 | `15-mermaid-after-frontmatter.md` | Regression | Mermaid diagram after frontmatter | Metadata renders first; Mermaid diagram renders as SVG/diagram below. |
| 16 | `16-mermaid-yaml-like-body.md` | Regression | Mermaid fence containing YAML-like body content | Leading metadata renders; Mermaid/code fence content is not mistaken for frontmatter. |
| 17 | `17-footnotes.md` | Regression | Footnotes after frontmatter | Metadata renders; footnote references and back-links work. |
| 18 | `18-syntax-highlighting.md` | Regression | Syntax-highlighted code after frontmatter | Metadata renders; fenced code is highlighted by highlight.js. |
| 19 | `19-table-thematic-break.md` | Regression | Markdown table and thematic break in body | Metadata renders; table and body thematic break render normally. |
| 20 | `20-long-invalid-block.md` | Feature/Security | Invalid frontmatter with long raw block | Parse-error card appears; long raw block is escaped/wrapped or scrollable; body renders below. |

## Security checks

- In fixtures 12 and 20, script-like strings must never execute.
- Raw invalid YAML in parse-error cards must be escaped inside preformatted text.
- Metadata values must not be passed through Markdown/HTML rendering.

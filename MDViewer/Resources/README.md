# MDViewer bundled web resources

This directory contains browser-side assets that are copied into the MDViewer macOS app bundle and loaded locally by `template.html`. These files must not be loaded from a CDN at runtime; MDViewer is expected to render offline.

## Vendored dependency governance

### `js-yaml`

- **Package:** [`js-yaml`](https://www.npmjs.com/package/js-yaml)
- **Version:** `4.1.0`
- **License:** MIT. The copied upstream `js-yaml@4.1.0` MIT license text is kept at `MDViewer/Resources/js-yaml.LICENSE`. Preserve the upstream license notice from the npm package when refreshing the vendored asset. If the minified bundle does not contain the full license text, keep this note and retain/copy the upstream package `LICENSE` in the same change according to project release practice.
- **Upstream source:** npm package `js-yaml@4.1.0`, official repository tag [`4.1.0`](https://github.com/nodeca/js-yaml/tree/4.1.0).
- **Browser bundle source path:** `dist/js-yaml.min.js` from the `js-yaml@4.1.0` npm package.
- **Local app resource path:** `MDViewer/Resources/js-yaml.min.js`.
- **Runtime:** Browser/WKWebView global build that exposes `window.jsyaml`; intended for MDViewer's supported macOS 13.0+ `WKWebView` JavaScript environment.
- **Network policy:** Must be packaged as a local app resource. Do not add CDN, dynamic import, or other network fallback behavior for runtime parsing.
- **Integrity:** SHA-256 for `MDViewer/Resources/js-yaml.min.js` is `45dc3dd03dc07a06705a2c2989b8c7f709013f04bd5386e3279d4e447f07ebd7` (recomputed from the checked-in local asset while adding this record).

#### Upgrade procedure

1. Choose the new `js-yaml` version and review upstream release notes for browser-bundle, YAML parsing, and security changes.
2. Download or extract `dist/js-yaml.min.js` from the official npm package/release artifact, not from an unverified mirror.
3. Replace `MDViewer/Resources/js-yaml.min.js` and preserve/copy required MIT license notices.
4. Update this section and the root `README.md` dependency table with the exact version, source, and any checksum/integrity note.
5. Confirm `template.html` loads the local `js-yaml.min.js` before frontmatter parsing code and does not reference the network.
6. Confirm the Xcode project/resource configuration copies `js-yaml.min.js` into the built `.app` bundle.
7. Smoke-test on the supported macOS 13.0+ `WKWebView` runtime with valid, malformed, empty, nested, scalar/array, CRLF, BOM, and HTML-like frontmatter values.

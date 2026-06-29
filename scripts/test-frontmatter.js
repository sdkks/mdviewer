#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert');

const repoRoot = path.resolve(__dirname, '..');
const templatePath = path.join(repoRoot, 'MDViewer', 'Resources', 'template.html');
const jsYamlPath = path.join(repoRoot, 'MDViewer', 'Resources', 'js-yaml.min.js');

const template = fs.readFileSync(templatePath, 'utf8');
const helperMatch = template.match(/\/\/ FRONTMATTER_HELPERS_START[\s\S]*?\/\/ FRONTMATTER_HELPERS_END/);
if (!helperMatch) {
  throw new Error('Unable to find frontmatter helper block in template.html');
}

function makeContext(loadParser = true) {
  const context = { console };
  context.window = context;
  vm.createContext(context);
  if (loadParser) {
    vm.runInContext(fs.readFileSync(jsYamlPath, 'utf8'), context, { filename: jsYamlPath });
  }
  vm.runInContext(helperMatch[0], context, { filename: templatePath });
  return context;
}

function makeRenderContext(loadParser = true) {
  const context = makeContext(loadParser);
  const markedPath = path.join(repoRoot, 'MDViewer', 'Resources', 'marked.min.js');
  const footnotePath = path.join(repoRoot, 'MDViewer', 'Resources', 'marked-footnote.min.js');
  vm.runInContext(fs.readFileSync(markedPath, 'utf8'), context, { filename: markedPath });
  vm.runInContext(fs.readFileSync(footnotePath, 'utf8'), context, { filename: footnotePath });
  vm.runInContext(`
    marked.use({
      renderer: {
        code({ text, lang }) {
          if (lang === 'mermaid') {
            return '<pre class="mermaid">' + text + '</pre>';
          }
          return false;
        }
      }
    });
    if (typeof markedFootnote !== 'undefined') {
      marked.use(markedFootnote({
        description: "Footnotes",
        placement: "document"
      }));
    }
    function renderWithTemplatePipeline(markdown) {
      const frontmatterResult = processFrontmatter(markdown);
      return {
        frontmatterResult,
        html: frontmatterResult.html + marked.parse(frontmatterResult.markdown)
      };
    }
  `, context, { filename: 'template-render-pipeline-smoke.js' });
  return context;
}

let context = makeContext(true);

let result = context.processFrontmatter('# Heading\n\nBody');
assert.strictEqual(result.status, 'none');
assert.strictEqual(result.markdown, '# Heading\n\nBody');
assert.strictEqual(result.html, '');

result = context.processFrontmatter('---\ntitle: Example\ntags:\n  - markdown\n  - viewer\n---\n# Heading');
assert.strictEqual(result.status, 'parsed');
assert.strictEqual(result.markdown, '# Heading');
assert.match(result.html, /<section class="frontmatter-card" aria-labelledby="frontmatter-title">/);
assert.match(result.html, /<div id="frontmatter-title" class="frontmatter-title" role="heading" aria-level="2">Metadata<\/div>/);
assert.match(result.html, /<th scope="row">title<\/th>/);
assert.match(result.html, /Example/);
assert.doesNotMatch(result.html, /---/);

result = context.processFrontmatter('\uFEFF---\r\ntitle: CRLF\r\n---\r\nBody');
assert.strictEqual(result.status, 'parsed');
assert.strictEqual(result.markdown, 'Body');
assert.match(result.html, /CRLF/);

result = context.processFrontmatter('\n---\ntitle: Not frontmatter\n---\nBody');
assert.strictEqual(result.status, 'none');
assert.strictEqual(result.markdown, '\n---\ntitle: Not frontmatter\n---\nBody');

result = context.processFrontmatter('---\n# Just a thematic break with no close');
assert.strictEqual(result.status, 'none');
assert.strictEqual(result.markdown, '---\n# Just a thematic break with no close');

result = context.processFrontmatter('# Body\n\n---\ntitle: Later\n---');
assert.strictEqual(result.status, 'none');
assert.strictEqual(result.markdown, '# Body\n\n---\ntitle: Later\n---');

result = context.processFrontmatter('---\n---\n# Body');
assert.strictEqual(result.status, 'empty');
assert.strictEqual(result.markdown, '# Body');
assert.strictEqual(result.html, '');

result = context.processFrontmatter('---\n- one\n- two\n---\nBody');
assert.strictEqual(result.status, 'parsed');
assert.match(result.html, /<th scope="row">value<\/th>/);
assert.match(result.html, /<ul class="frontmatter-value-list">/);
assert.match(result.html, /one/);

result = context.processFrontmatter('---\npublished: 2026-06-29\nmissing:\nnested:\n  level1:\n    level2:\n      level3:\n        level4: deep\nlong: "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz"\n---\nBody');
assert.strictEqual(result.status, 'parsed');
assert.match(result.html, /2026-06-29T00:00:00\.000Z/);
assert.match(result.html, /<span class="frontmatter-null">null<\/span>/);
assert.match(result.html, /<pre class="frontmatter-json-fallback"><code>/);
assert.match(result.html, /level4/);
assert.match(result.html, /abcdefghijklmnopqrstuvwxyz/);

result = context.processFrontmatter('---\ntitle: "<script>alert(1)</script>"\n---\nBody');
assert.strictEqual(result.status, 'parsed');
assert.match(result.html, /&lt;script&gt;alert\(1\)&lt;\/script&gt;/);
assert.doesNotMatch(result.html, /<script>alert/);

result = context.processFrontmatter('---\ntitle: [broken\n---\n# Body');
assert.strictEqual(result.status, 'invalid');
assert.strictEqual(result.markdown, '# Body');
assert.match(result.html, /<section class="frontmatter-error" role="alert" aria-labelledby="frontmatter-error-title">/);
assert.match(result.html, /Frontmatter parse error/);
assert.match(result.html, /The document body is rendered below/);
assert.match(result.html, /<details open><summary>Original frontmatter<\/summary><pre><code>/);
assert.match(result.html, /title: \[broken/);

context = makeContext(false);
result = context.processFrontmatter('---\ntitle: Example\n---\n# Body');
assert.strictEqual(result.status, 'parser-missing');
assert.strictEqual(result.markdown, '# Body');
assert.match(result.html, /Frontmatter parser unavailable/);
assert.match(result.html, /title: Example/);

context = makeRenderContext(true);

result = context.renderWithTemplatePipeline('# No frontmatter\n\n| A | B |\n| - | - |\n| 1 | 2 |\n\n---\n\n```js\nconst fence = "---";\n```');
assert.strictEqual(result.frontmatterResult.status, 'none');
assert.match(result.html, /<h1[^>]*>No frontmatter<\/h1>/);
assert.match(result.html, /<table>/);
assert.match(result.html, /<hr>/);
assert.match(result.html, /language-js/);
assert.match(result.html, /const fence/);
assert.match(result.html, /---/);
assert.doesNotMatch(result.html, /frontmatter-card/);
assert.doesNotMatch(result.html, /frontmatter-error/);

result = context.renderWithTemplatePipeline('---\ntitle: Diagram Doc\n---\n```mermaid\nflowchart TD\n  A[---] --> B\n```');
assert.strictEqual(result.frontmatterResult.status, 'parsed');
assert.match(result.html, /frontmatter-card/);
assert.match(result.html, /<pre class="mermaid">flowchart TD/);
assert.match(result.html, /A\[---\] --&gt; B|A\[---\] --&amp;gt; B|A\[---\] --> B/);

result = context.renderWithTemplatePipeline('---\ntitle: Footnote Doc\n---\nFootnote ref.[^1]\n\n[^1]: Footnote body.');
assert.strictEqual(result.frontmatterResult.status, 'parsed');
assert.match(result.html, /frontmatter-card/);
assert.match(result.html, /footnotes/);
assert.match(result.html, /Footnote body/);

result = context.renderWithTemplatePipeline('---\ntitle: Body fence\n---\n```yaml\n---\ntitle: Not frontmatter\n---\n```\n\nAfter.');
assert.strictEqual(result.frontmatterResult.status, 'parsed');
assert.strictEqual(result.frontmatterResult.markdown, '```yaml\n---\ntitle: Not frontmatter\n---\n```\n\nAfter.');
assert.match(result.html, /language-yaml/);
assert.match(result.html, /title: Not frontmatter/);
assert.match(result.html, /After/);

function normalizeHeaders(headers) {
  return JSON.parse(JSON.stringify(headers));
}

const h2OnlyHeaders = normalizeHeaders(context.collectH1H2HeadersFromElements([
  { tagName: 'H2', textContent: 'Overview', id: 'overview', closest: () => null },
  { tagName: 'H2', textContent: 'Details', id: 'details', closest: () => null }
]));
assert.deepStrictEqual(h2OnlyHeaders, [
  { text: 'Overview', id: 'overview', h2s: [{ text: 'Details', id: 'details' }] }
]);

const mixedHeaders = normalizeHeaders(context.collectH1H2HeadersFromElements([
  { tagName: 'H1', textContent: 'Title', id: 'title', closest: () => null },
  { tagName: 'H2', textContent: 'Section', id: 'section', closest: () => null }
]));
assert.deepStrictEqual(mixedHeaders, [
  { text: 'Title', id: 'title', h2s: [{ text: 'Section', id: 'section' }] }
]);

const ignoredFrontmatterHeaders = normalizeHeaders(context.collectH1H2HeadersFromElements([
  { tagName: 'H2', textContent: 'Metadata', id: 'frontmatter-title', closest: (selector) => selector.includes('frontmatter-card') ? {} : null },
  { tagName: 'H2', textContent: 'Real Section', id: 'real-section', closest: () => null }
]));
assert.deepStrictEqual(ignoredFrontmatterHeaders, [
  { text: 'Real Section', id: 'real-section', h2s: [] }
]);

console.log('frontmatter helper and Markdown extension regression tests passed');

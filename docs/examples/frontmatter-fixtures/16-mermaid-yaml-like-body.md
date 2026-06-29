---
title: Mermaid YAML-like Body
kind: regression
---

# Mermaid With YAML-like Content

```mermaid
flowchart LR
  A["---"] --> B["title: not frontmatter"]
  B --> C["---"]
```

The YAML-like strings inside the Mermaid fence are body content only.

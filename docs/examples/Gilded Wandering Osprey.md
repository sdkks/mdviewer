# Gilded Wandering Osprey

A walkthrough of B-tree internals, indexing strategies, and query planning in relational databases.

## B-Tree Structure

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed augue ipsum, egestas nec, vestibulum et, malesuada adipiscing, dui. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae.

A B-tree maintains sorted data and allows logarithmic searches, insertions, and deletions:

```
              [30 | 70]
             /    |    \
      [10|20]  [40|50|60]  [80|90]
```

Each node holds between `t-1` and `2t-1` keys, where `t` is the minimum degree.

## Index Types

| Type | Best For | Notes |
|------|----------|-------|
| B-tree | Range queries, equality | Default in most databases |
| Hash | Equality only | Faster than B-tree for `=` |
| GiST | Geometric, full-text | Extensible framework |
| BRIN | Large append-only tables | Tiny, lossy |
| Partial | Subset of rows | Reduces index size |

## Query Planning

Proin neque massa, cursus ut, gravida ut, lobortis eget, lacus. Sed diam. Praesent fermentum tempor tellus.

The query planner estimates row counts using table statistics and chooses between:

- **Sequential scan** — reads the entire table; best for large fractions
- **Index scan** — follows B-tree to matching rows; best for selective predicates  
- **Index-only scan** — all required columns in the index; no heap access needed
- **Bitmap scan** — combines multiple indexes via bitwise AND/OR

## VACUUM and Bloat

Nullam eu ante vel est convallis dignissim. Fusce suscipit, wisi nec facilisis facilisis, est dui fermentum leo, quis tempor ligula erat quis odio.

Dead tuples from updates and deletes accumulate until `VACUUM` reclaims them. Without regular vacuuming, table and index bloat degrades performance over time.

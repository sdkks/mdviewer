# Silver Fleeting Numbat

A practical reference on API versioning strategies, backward compatibility, and deprecation workflows.

## Why Version APIs?

APIs are contracts. Breaking a contract breaks clients. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vivamus magna. Cras in mi at felis aliquet congue. Ut a est eget ligula molestie gravida.

## Versioning Strategies

### URI Versioning

```
GET /v1/users/123
GET /v2/users/123
```

Explicit and cache-friendly. The most common approach for REST APIs.

### Header Versioning

```
Accept: application/vnd.api+json;version=2
```

Keeps URIs clean but is invisible to casual users and harder to test in a browser.

### Query Parameter

```
GET /users/123?version=2
```

Easy to test. Can be cached but requires careful cache-key configuration.

## Breaking vs Non-Breaking Changes

| Change | Breaking? |
|--------|-----------|
| Add optional field to response | No |
| Remove field from response | Yes |
| Add required request parameter | Yes |
| Add optional request parameter | No |
| Change field type | Yes |
| Rename endpoint | Yes (add alias first) |

## Deprecation Workflow

Curabitur pretium tincidunt lacus. Nulla gravida orci a odio. Nullam varius, turpis molestie dictum semper.

1. Announce deprecation with a sunset date in docs and `Sunset` response header
2. Maintain the old version for at least one full release cycle
3. Monitor usage metrics; reach out to active consumers before shutdown
4. Return `410 Gone` after sunset

Nullam eu ante vel est convallis dignissim. Fusce suscipit, wisi nec facilisis facilisis, est dui fermentum leo.

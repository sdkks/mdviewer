# Ember Tangled Quoll

A reference document on observability pillars — logs, metrics, and traces — and how they complement each other.

## The Three Pillars

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aliquam erat volutpat. Nam dui mi, tincidunt quis, accumsan porttitor, facilisis luctus, metus.

### Logs

Structured event records emitted at points of interest. Best for debugging specific incidents.

```json
{
  "ts": "2026-04-25T14:32:01Z",
  "level": "error",
  "service": "payments",
  "trace_id": "abc123",
  "msg": "charge declined",
  "code": "insufficient_funds"
}
```

### Metrics

Numeric time-series data aggregated over a window. Best for alerting and capacity planning.

| Metric Type | Example |
|-------------|---------|
| Counter | `http_requests_total` |
| Gauge | `memory_usage_bytes` |
| Histogram | `request_duration_seconds` |
| Summary | `rpc_duration_quantiles` |

### Traces

Phasellus ultrices nulla quis nibh. Quisque a lectus. Donec consectetuer ligula vulputate sem tristique cursus. Nam nulla quam, gravida non, commodo a, sodales sit amet, nisi.

Distributed traces link spans across service boundaries, reconstructing the full call graph for a single request.

## Correlation

The three signals are most powerful when correlated. A spike in the `error_rate` metric should link to log lines containing the failing `trace_id`, which in turn shows the full call path via the trace.

Phasellus purus. Pellentesque tristique imperdiet tortor. Nam euismod tellus id erat.

# Jade Nimble Cormorant

An introduction to garbage collection algorithms and their trade-offs in managed runtimes.

## Why Garbage Collection?

Manual memory management is error-prone. Common bugs include use-after-free, double-free, and memory leaks. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec a diam lectus. Sed sit amet ipsum mauris.

## Algorithms

### Mark and Sweep

Two phases:
1. **Mark** — traverse all live objects from GC roots, marking reachable ones
2. **Sweep** — scan the heap and free unmarked objects

Simple but causes stop-the-world pauses proportional to heap size.

### Copying Collector

Divides the heap into two semispaces. Live objects are copied to the other semispace; the original is wiped clean. Eliminates fragmentation automatically.

```
[From Space: A B . C . . D] → copy → [To Space: A B C D . . . .]
```

### Generational GC

Maecenas nec odio et ante tincidunt tempus. Donec vitae sapien ut libero venenatis faucibus.

Objects in most programs either die young or live long. Generational collectors exploit this:

| Generation | Frequency | Algorithm |
|------------|-----------|-----------|
| Young (nursery) | Very frequent | Copying |
| Old (tenured) | Infrequent | Mark-sweep or mark-compact |

### Concurrent and Incremental

Modern collectors (G1, ZGC, Shenandoah) interleave GC work with application threads to reduce pause times. Trade throughput for latency.

## Trade-offs

Fusce fermentum. Nullam varius nulla quis sapien. Sed malesuada augue ut risus condimentum, at commodo sem gravida.

Throughput-oriented collectors (parallel GC) maximise total work done. Latency-oriented collectors (ZGC) target sub-millisecond pauses. Choose based on your SLA — a batch job tolerates long pauses; a trading system does not.

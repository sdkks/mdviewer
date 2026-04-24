# Dusty Hollow Wren

An exploration of event-driven architecture patterns and message broker design.

## Introduction

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur pretium tincidunt lacus. Nulla gravida orci a odio. Nullam varius, turpis molestie dictum semper, arcu ligula aliquet nisi.

## Core Concepts

Event-driven systems decouple producers from consumers through an intermediary. The three main topologies are:

- **Point-to-point** — one producer, one consumer queue
- **Publish-subscribe** — one producer, many subscriber channels
- **Event streaming** — ordered, replayable log of events

## Message Ordering

Strict ordering guarantees are expensive. Most brokers offer:

1. Per-partition ordering (Kafka)
2. Per-queue ordering (SQS FIFO)
3. Best-effort ordering (SNS, basic queues)

```
Producer → [Partition 0] → Consumer A
         → [Partition 1] → Consumer B
         → [Partition 2] → Consumer C
```

## Delivery Semantics

| Semantic | Description | Use Case |
|----------|-------------|----------|
| At most once | May lose messages | Metrics, telemetry |
| At least once | May duplicate | Payments with idempotency |
| Exactly once | No loss or duplication | Financial ledgers |

## Backpressure

Fusce fermentum. Nullam varius nulla. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Suspendisse potenti.

When consumers fall behind producers, backpressure mechanisms prevent memory exhaustion. Common approaches include flow control signals, consumer-side throttling, and dead-letter queues for poison messages.

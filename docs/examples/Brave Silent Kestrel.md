# Brave Silent Kestrel

A practical guide to container orchestration patterns and resource scheduling strategies.

## Overview

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Vestibulum tortor quam, feugiat vitae, ultricies eget, tempor sit amet, ante.

## Scheduling Strategies

Container schedulers must balance several competing concerns when placing workloads:

1. Resource availability across nodes
2. Affinity and anti-affinity rules
3. Priority classes and preemption
4. Topology spread constraints

### Bin Packing vs Spread

**Bin packing** maximises utilisation by filling nodes to capacity before moving to the next. Useful for cost optimisation in batch workloads.

**Spread scheduling** distributes replicas evenly across nodes and zones. Preferred for high-availability services.

## Resource Requests and Limits

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "250m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

Donec eu libero sit amet quam egestas semper. Aenean ultricies mi vitae est. Mauris placerat eleifend leo. Quisque sit amet est et sapien ullamcorper pharetra.

## Eviction and Quality of Service

Pods are assigned one of three QoS classes:

- **Guaranteed** — requests equal limits for all containers
- **Burstable** — requests set but below limits
- **BestEffort** — no requests or limits set

## Further Reading

Vestibulum erat wisi, condimentum sed, commodo vitae, ornare sit amet, wisi. Aenean fermentum, elit eget tincidunt condimentum, eros ipsum rutrum orci.

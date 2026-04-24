# Crimson Drifting Ibis

Notes on cryptographic hash functions, collision resistance, and their applications in data integrity.

## What Is a Hash Function?

A hash function maps arbitrary-length input to a fixed-length digest. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer nec odio. Praesent libero. Sed cursus ante dapibus diam.

## Properties

| Property | Description |
|----------|-------------|
| Deterministic | Same input always produces same output |
| One-way | Computationally infeasible to reverse |
| Collision resistant | Hard to find two inputs with the same output |
| Avalanche effect | Small input change → drastically different output |

## Common Algorithms

### SHA-256

Currently the most widely deployed hash in security contexts. Produces a 256-bit digest.

```
echo -n "hello" | shasum -a 256
# 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
```

### SHA-3 (Keccak)

Sed nisi. Nulla quis sem at nibh elementum imperdiet. Duis sagittis ipsum. Praesent mauris. Fusce nec tellus sed augue semper porta.

### BLAKE3

Designed for speed and security. Parallelises across CPU cores and outperforms MD5 in throughput while providing cryptographic guarantees.

## Merkle Trees

Hash functions are the building block of Merkle trees, used extensively in:

- Git object storage
- Bitcoin transaction verification
- Certificate transparency logs

Mauris massa. Vestibulum lacinia arcu eget nulla. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos hymenaeos.

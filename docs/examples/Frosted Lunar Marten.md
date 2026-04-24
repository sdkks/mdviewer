# Frosted Lunar Marten

Concepts in functional programming: pure functions, immutability, and algebraic data types.

## Pure Functions

A pure function has two properties:

1. Given the same input, it always returns the same output
2. It produces no side effects

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam feugiat, turpis at pulvinar vulputate, erat libero tristique tellus, nec bibendum odio risus sit amet ante.

```haskell
-- Pure
add :: Int -> Int -> Int
add x y = x + y

-- Impure (reads external state)
getTimestamp :: IO Int
getTimestamp = ...
```

## Immutability

Immutable data structures eliminate an entire class of bugs caused by shared mutable state. Aliquam nibh. Mauris ac mauris sed pede pellentesque fermentum.

## Algebraic Data Types

### Sum Types (Tagged Unions)

```rust
enum Result<T, E> {
    Ok(T),
    Err(E),
}
```

### Product Types (Records)

```rust
struct Point {
    x: f64,
    y: f64,
}
```

## Composition Over Inheritance

| OOP | Functional |
|-----|-----------|
| Class hierarchy | Function composition |
| Mutable state | Immutable values |
| Side effects in methods | Effects pushed to boundaries |
| Polymorphism via subtype | Polymorphism via type classes |

Maecenas ligula. Pellentesque viverra vulputate enim. Aliquam erat volutpat. Nam dui mi, tincidunt quis, accumsan porttitor, facilisis luctus, metus.

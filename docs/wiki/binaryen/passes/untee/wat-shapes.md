---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-untee-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-23-untee-primary-sources.md
  - ../../../raw/research/0347-2026-04-25-untee-current-main-recheck.md
  - ../../../raw/research/0185-2026-04-21-untee-binaryen-research.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Untee.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/untee.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./flattening-code-pushing-and-tee-boundaries.md
  - ./starshine-strategy.md
---

# `untee` WAT shapes

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-23-untee-primary-sources.md`](../../../raw/binaryen/2026-04-23-untee-primary-sources.md) and the 2026-04-25 current-main bridge in [`../../../raw/binaryen/2026-04-25-untee-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-untee-current-main-recheck.md).

This page is the beginner-friendly shape catalog for Binaryen `untee`.

The pass is small, so the real learning goal is not breadth.
It is learning exactly which `local.tee` families are rewritten, which ones are preserved, and why.

## Reading rule

Whenever you see `local.tee`, think:

- write the value into the local
- also produce that same value as the expression result

`untee` rewrites that into:

- explicit `local.set`
- followed by explicit `local.get`

unless the tee is already unreachable.

---

## Positive family 1: dropped scalar tee

### Input shape

```wat
(drop (local.tee $x (i32.const 1)))
```

### Output shape

```wat
(drop
  (block (result i32)
    (local.set $x
      (i32.const 1))
    (local.get $x)))
```

### Why

The `drop` still needs a value to drop.
So the tee cannot become just a plain `local.set`.
Binaryen must keep the produced result, and it does so by reading the local back.

---

## Positive family 2: non-integer scalar tee

### Input shape

```wat
(drop (local.tee $y (f64.const 2)))
```

### Output shape

```wat
(drop
  (block (result f64)
    (local.set $y
      (f64.const 2))
    (local.get $y)))
```

### Why

The pass is not i32-only.
It uses the function's declared local type for the synthetic get.

---

## Positive family 3: tee feeding another set

### Input shape

```wat
(local.set $x
  (local.tee $x
    (i32.const 3)))
```

### Output shape

```wat
(local.set $x
  (block (result i32)
    (local.set $x
      (i32.const 3))
    (local.get $x)))
```

### Why

The inner tee's result is still needed by the outer `local.set`.
So the pass must preserve the value result after making the write explicit.

---

## Positive family 4: nested tee chain

### Input shape

```wat
(local.set $x
  (local.tee $x
    (local.tee $x
      (i32.const 3))))
```

### Output shape idea

```wat
(local.set $x
  (block (result i32)
    (local.set $x
      (block (result i32)
        (local.set $x
          (i32.const 3))
        (local.get $x)))
    (local.get $x)))
```

### Why

Because the walk is postorder, Binaryen expands the inner tee first and the outer tee second.
That creates nested result blocks.

---

## Bailout family: unreachable tee

### Input shape

```wat
(drop (local.tee $x (unreachable)))
```

### Output shape

```wat
(drop (unreachable))
```

### Why

A get-after-unreachable result would be meaningless.
If execution never reaches the tee, there is no write and no produced value to read back.
So Binaryen removes the tee shell entirely.

---

## Preserved family: ordinary `local.set`

### Input shape

```wat
(local.set $x (i32.const 1))
```

### Output shape

```wat
(local.set $x (i32.const 1))
```

### Why

`untee` only rewrites real tees.
Ordinary sets are outside its scope.

---

## Preserved family: everything that is not a tee

The pass does not directly target:

- `local.get`
- `block`
- `if`
- `loop`
- branches
- calls
- arithmetic expressions

Those may still appear around a rewritten tee, but they are not candidate kinds by themselves.

---

## What a future Starshine port must preserve

- tee-only candidate selection
- set-plus-get expansion for reachable tees
- declared-local-type reuse for the synthetic get
- inside-out expansion for nested tees
- unreachable-tee deletion instead of wrapper construction
- the explicit distinction between visible wrapper structure and the smaller semantic goal of flattening hidden side effects

## Sources

- [`../../../raw/binaryen/2026-04-25-untee-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-untee-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-23-untee-primary-sources.md`](../../../raw/binaryen/2026-04-23-untee-primary-sources.md)
- [`../../../raw/research/0347-2026-04-25-untee-current-main-recheck.md`](../../../raw/research/0347-2026-04-25-untee-current-main-recheck.md)
- [`../../../raw/research/0185-2026-04-21-untee-binaryen-research.md`](../../../raw/research/0185-2026-04-21-untee-binaryen-research.md)
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Untee.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/untee.wast>

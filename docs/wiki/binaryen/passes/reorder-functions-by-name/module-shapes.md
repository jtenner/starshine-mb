---
kind: concept
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0180-2026-04-21-reorder-functions-by-name-binaryen-research.md
  - ../../../raw/research/0213-2026-04-21-reorder-functions-by-name-source-confirmation-followup.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ReorderFunctions.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/reorder-functions-by-name.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ../reorder-functions/index.md
  - ../reorder-globals/index.md
  - ../reorder-locals/index.md
---

# `reorder-functions-by-name` module-shape catalog

This pass is not really about inner WAT expression shapes.
It is about **module-level function ordering**.
So the most honest examples here are tiny module-order families.

## How to read these examples

Each example focuses on the real `version_129` contract:

- look only at internal function names
- sort ascending
- leave bodies alone

The first four positive families below are **directly anchored to the dedicated official lit file**. Later preserved/surprise notes are source-derived boundaries from the reviewed comparator and pass registration.

## Positive family 1: reverse order normalizes to `$a`, `$b`, `$c`

### Before

```wat
(module
  (func $c (result i32)
    (i32.const 30)
  )
  (func $b (result i32)
    (i32.const 20)
  )
  (func $a (result i32)
    (i32.const 10)
  )
)
```

### After

```wat
(module
  (func $a (result i32)
    (i32.const 10)
  )
  (func $b (result i32)
    (i32.const 20)
  )
  (func $c (result i32)
    (i32.const 30)
  )
)
```

### Durable lesson

The pass is a lexical declaration sorter.

## Positive family 2: already sorted modules are no-ops

### Before

```wat
(module
  (func $a (result i32)
    (i32.const 10)
  )
  (func $b (result i32)
    (i32.const 20)
  )
  (func $c (result i32)
    (i32.const 30)
  )
)
```

### After

The order stays the same because it is already ascending by name.

### Durable lesson

This pass can serve as a deterministic normalization step for debugging without necessarily changing every module.

## Positive family 3: middle swap also normalizes to `$a`, `$b`, `$c`

### Before

```wat
(module
  (func $b (result i32)
    (i32.const 20)
  )
  (func $a (result i32)
    (i32.const 10)
  )
  (func $c (result i32)
    (i32.const 30)
  )
)
```

### After

```wat
(module
  (func $a (result i32)
    (i32.const 10)
  )
  (func $b (result i32)
    (i32.const 20)
  )
  (func $c (result i32)
    (i32.const 30)
  )
)
```

### Durable lesson

Mixed declaration permutations still normalize to the same ascending name order.

## Positive family 4: front/back mix also normalizes to `$a`, `$b`, `$c`

### Before

```wat
(module
  (func $c (result i32)
    (i32.const 30)
  )
  (func $a (result i32)
    (i32.const 10)
  )
  (func $b (result i32)
    (i32.const 20)
  )
)
```

### After

```wat
(module
  (func $a (result i32)
    (i32.const 10)
  )
  (func $b (result i32)
    (i32.const 20)
  )
  (func $c (result i32)
    (i32.const 30)
  )
)
```

### Durable lesson

The dedicated lit file proves the core positive family directly, not just by source inference.

## Preserved family 1: body complexity does not matter

### Before

```wat
(module
  (func $z
    (drop (i32.const 1)))
  (func $a
    (loop $L
      (br $L)))
)
```

### Why it changes

`$a` moves before `$z` only because of its name.
The loop in `$a` and the trivial body in `$z` are irrelevant.

### Durable lesson

This pass ignores function-body structure entirely.

## Preserved family 1: lexical order ignores static use counts

### Before

```wat
(module
  (func $z_helper)
  (func $a_entry
    (call $z_helper)
    (call $z_helper)
    (call $z_helper))
)
```

### Why this matters

A beginner might expect `$z_helper` to move earlier because it is called many times.
That is what the sibling `reorder-functions` reasons about, not this pass.

### Durable lesson

`reorder-functions-by-name` ignores call-frequency-like information entirely.

## Preserved family 2: start/export/element references do not matter

### Sketch

```wat
(module
  (table 1 funcref)
  (func $z_api)
  (func $a_main)
  (start $z_api)
  (export "run" (func $z_api))
  (elem (i32.const 0) func $z_api)
)
```

### Why this matters

The sibling `reorder-functions` would count those surfaces.
This pass still just sorts lexically.

### Durable lesson

Module-level reference surfaces are outside this pass's contract.

## Preserved family 3: bodies stay unchanged

### Before

```wat
(module
  (func $b (result i32)
    (i32.const 7))
  (func $a (result i32)
    (call $b))
)
```

### After

Only declaration order may change.
The bodies themselves stay the same.

### Durable lesson

This is a declaration-order pass, not a body optimizer.

## Surprise family 1: this is a different pass from `reorder-functions`

The sibling pass from the same file uses:

- direct-call counts
- start/export/element bumps
- descending-count and descending-name sorting

This by-name pass uses none of those.

### Durable lesson

Shared source file does not mean shared ordering policy.

## Surprise family 2: this is about Binaryen internal names, not source comments or pretty layout

The pass sorts by `Name` values inside Binaryen's IR.
So it should be taught as lexical sorting over Binaryen's internal function identifiers, not as a full source-text formatter.

## Neighbor contrast: why this is even smaller than `reorder-functions`

`reorder-functions` at least has a tiny static counting prepass.
`reorder-functions-by-name` does not even do that.
It is the simplest possible module-function ordering rule.

## Condensed porting checklist

If a future Starshine implementation disagrees with Binaryen, check these first:

1. Did it keep this as a separate public pass from `reorder-functions`?
2. Did it sort by ascending function name?
3. Did it avoid looking at call/start/export/element surfaces?
4. Did it leave bodies untouched?
5. Did it keep the pass framed as debugging-oriented rather than size-oriented?

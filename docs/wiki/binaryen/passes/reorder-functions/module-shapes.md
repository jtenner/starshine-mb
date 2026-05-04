---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-reorder-functions-current-main-recheck.md
  - ../../../raw/research/0439-2026-05-04-reorder-functions-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-reorder-functions-primary-sources.md
  - ../../../raw/research/0297-2026-04-24-reorder-functions-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0179-2026-04-21-reorder-functions-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderFunctions.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-functions-by-name.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../reorder-globals/index.md
  - ../reorder-locals/index.md
---

# `reorder-functions` module-shape catalog

This pass is not really about inner WAT expression shapes.
It is about **module-level function ordering**.
So the most honest examples here are tiny module-order families.

## How to read these examples

Each example focuses on which functions get extra static-use counts from the real `version_129` source captured in [`../../../raw/binaryen/2026-04-24-reorder-functions-primary-sources.md`](../../../raw/binaryen/2026-04-24-reorder-functions-primary-sources.md):

- direct calls
- start function
- function exports
- element segment contents

Unless noted otherwise, the order examples below are **inferences from the reviewed source comparator**, not copied oracle output.

The family layout below was rechecked against current main on 2026-05-04 and still matches the source-backed teaching model.

## Positive family 1: one heavily called helper moves earlier

### Before

```wat
(module
  (func $cold)
  (func $hot)
  (func $main
    (call $hot)
    (call $hot)
    (call $hot))
)
```

### Why it changes

`$hot` gets three direct-call count bumps.
`$cold` gets none.
So `reorder-functions` wants `$hot` earlier than `$cold`.

### Durable lesson

The pass rewards **repeated direct callers**, not source order.

## Positive family 2: start function gets counted even without callers

### Before

```wat
(module
  (func $helper)
  (func $entry)
  (start $entry)
)
```

### Why it changes

`$entry` gets one count bump from `module->start` even though no function body calls it.

### Durable lesson

Module entrypoints count as static use.

## Positive family 3: exported API gets counted even without internal callers

### Before

```wat
(module
  (func $api)
  (func $internal)
  (export "run" (func $api))
)
```

### Why it changes

`$api` gets one count bump because it is a function export.

### Durable lesson

External visibility matters to the orderer even when internal call traffic is absent.

## Positive family 4: element segment contents count too

### Before

```wat
(module
  (table 2 funcref)
  (func $tabulated)
  (func $other)
  (elem (i32.const 0) func $tabulated)
)
```

### Why it changes

`$tabulated` gets one count bump through `ElementUtils::iterAllElementFunctionNames(...)`.

### Durable lesson

Table initializer references are part of the real static-use model.

## Positive family 5: counts accumulate across different surfaces

### Before

```wat
(module
  (table 1 funcref)
  (func $f)
  (func $g
    (call $f))
  (export "api" (func $f))
  (elem (i32.const 0) func $f)
)
```

### Why it changes

`$f` gets:

- one direct-call count
- one export count
- one element-segment count

That combined score can dominate the order even in a tiny module.

### Durable lesson

The pass does not distinguish “kinds” of static use once they are counted.
They all feed the same integer score.

## Positive family 6: equal counts do **not** preserve source order

### Before

```wat
(module
  (func $a)
  (func $b)
  (func $c)
)
```

### After, by source comparator inference

All counts are `0`, so the tie breaker decides the order.
The reviewed source uses descending name on ties, so the order becomes conceptually:

```wat
(module
  (func $c)
  (func $b)
  (func $a)
)
```

### Durable lesson

This pass is deterministic, but it is **not** stable by original order.

## Preserved family 1: no body rewrite at all

### Before

```wat
(module
  (func $a (result i32)
    (i32.const 10))
  (func $b (result i32)
    (call $a))
)
```

### After

Only declaration order may change.
The bodies themselves stay the same.

### Durable lesson

This is a declaration-order pass, not a body optimizer.

## Preserved family 2: by-name sibling is a different contract

### `reorder-functions-by-name`

The shipped `reorder-functions-by-name.wast` demonstrates the sibling behavior:

- ascending lexical name order
- no body mutation

### Durable lesson

Do not merge the two passes mentally.
One is lexical/debug order.
The other is count-based size order.

## Surprise family 1: `ref.func`-only references are undercounted today

### Sketch

```wat
(module
  (func $only-ref-func)
  (func $user
    (drop (ref.func $only-ref-func)))
)
```

### Why this is surprising

A beginner might expect `$only-ref-func` to gain count credit.
The reviewed source leaves that as an explicit TODO instead.

### Durable lesson

`version_129` `reorder-functions` is intentionally incomplete with respect to all possible function-reference surfaces.

## Surprise family 2: declaration mentions are undercounted today

The file also leaves declaration-section counting as TODO.
So a future port should not silently add it if the goal is `version_129` parity.

## Surprise family 3: this is not profile-guided hotness

Even if a function is dynamically hot at runtime, that does not matter unless it is hot under the small **static** count model in the source.

### Durable lesson

“Access frequency” here means “how many static mentions Binaryen counts,” not “what a profiler observed.”

## Neighbor contrast: why this is simpler than `reorder-globals`

`reorder-globals` must preserve dependency order and uses a size model that reasons about index widths and under-`128` cutoffs.
`reorder-functions` just totals counts and sorts.

That simplicity is a core part of its identity.

## Starshine representation caveat

These examples show logical module-order changes. In Binaryen's IR, body references still point at the same named functions after the list reorder. In Starshine's current lowered representation, function references are numeric `FuncIdx` values; a future port therefore needs the remap plan in [`./starshine-strategy.md`](./starshine-strategy.md) to keep calls, start/export/element references, and metadata pointed at the same logical functions.

## Condensed porting checklist

If a future Starshine implementation disagrees with Binaryen, check these first:

1. Did it count only direct `call` targets?
2. Did it add bumps for start, exports, and element-segment function names?
3. Did it avoid counting `ref.func` and declaration mentions, as `version_129` still does?
4. Did it sort by descending count?
5. Did it use descending-name tie breaks rather than source-order stability?

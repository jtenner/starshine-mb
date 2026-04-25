---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-reorder-globals-always-primary-sources.md
  - ../../../raw/research/0336-2026-04-25-reorder-globals-always-source-bridge.md
  - ../../../raw/research/0188-2026-04-21-reorder-globals-always-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals-real.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ../reorder-globals/index.md
---

# `reorder-globals-always` WAT and module shapes

This page is the beginner-friendly shape catalog for Binaryen `reorder-globals-always`.

The easiest way to read the page is:

- first ask whether the module order is dependency-safe
- then ask whether ordinary `reorder-globals` would no-op because the module is tiny
- if yes, that is exactly the kind of shape where `reorder-globals-always` becomes easiest to see

## Positive shape 1: a tiny module can still reorder

### Before

```wat
(module
  (global $cold i32 (i32.const 0))
  (global $hot i32 (i32.const 1))
  (func
    (drop (global.get $hot))
    (drop (global.get $hot))
    (drop (global.get $cold))))
```

### After under `reorder-globals-always`, conceptually

```wat
(module
  (global $hot i32 (i32.const 1))
  (global $cold i32 (i32.const 0))
  (func
    (drop (global.get $hot))
    (drop (global.get $hot))
    (drop (global.get $cold))))
```

The exact printed order may vary only by ties, but the important shape is:

- the hotter independent global moves earlier
- even though the module is too small for public `reorder-globals` to care

## Positive shape 2: dependencies still beat raw popularity

### Before

```wat
(module
  (global $base i32 (i32.const 0))
  (global $derived i32 (global.get $base))
  (func
    (drop (global.get $derived))
    (drop (global.get $derived))))
```

### After

No illegal swap.
`$base` must stay before `$derived`.

This is a positive teaching shape because it shows that the sibling still preserves validity.
It is not just “sort by usage and hope.”

## Positive shape 3: independent hot global can still move ahead of a valid dependency chain

### Before

```wat
(module
  (global $a i32 (i32.const 0))
  (global $b i32 (global.get $a))
  (global $hot i32 (i32.const 9))
  (func
    (drop (global.get $hot))
    (drop (global.get $hot))
    (drop (global.get $b))))
```

### After, conceptually

```wat
(module
  (global $hot i32 (i32.const 9))
  (global $a i32 (i32.const 0))
  (global $b i32 (global.get $a))
  ...)
```

Why this is valid:

- `$hot` is independent
- `$a` still stays before `$b`
- the sibling is free to move the independent hot global earlier

## Positive shape 4: `global.set` traffic counts too

### Before

```wat
(module
  (global $writer (mut i32) (i32.const 0))
  (global $reader i32 (i32.const 1))
  (func
    (global.set $writer (i32.const 3))
    (global.set $writer (i32.const 4))
    (drop (global.get $reader))))
```

A beginner might guess `$reader` is hotter because it is read.
But Binaryen counts writes too.

So `reorder-globals-always` can still prefer `$writer`.

## Positive shape 5: fresh-helper-global repair after `GlobalStructInference`

### Conceptual before nested rerun

A previous pass has inserted a fresh helper global late in the global list even though another global or function-body use now expects it earlier.

### Conceptual after nested `reorder-globals-always`

The fresh helper global is moved earlier so the module's declaration order becomes valid and stable again.

This shape matters because it proves the sibling is not only a test convenience.
It also acts as a real internal small-module repair tool.

## Negative shape 1: imports do not move after defined globals

### Before

```wat
(module
  (import "env" "g" (global $imp i32))
  (global $hot i32 (i32.const 1))
  (func (drop (global.get $hot)) (drop (global.get $hot))))
```

### After

No reorder that moves `$hot` before `$imp`.

Imports-first ordering remains part of the sibling contract.

## Negative shape 2: already-best or tied orders can stay stable

### Before

A tiny module where multiple candidate orders have equal estimated synthetic cost.

### After

Binaryen keeps the earliest strict minimum, so the original-ish candidate can survive.

That means the sibling is not “reorder whenever possible.”
It is still a stable best-candidate selector.

## Negative shape 3: symbol names do not drive the order

### Before

```wat
(module
  (global $zzz i32 (i32.const 0))
  (global $aaa i32 (i32.const 1)))
```

### After

No special lexicographic behavior just because the names differ.
The order is determined by counts, dependencies, imports, and tie behavior, not by symbol spelling.

## What beginners most often misread

### Misread 1: `always` means all small modules must visibly change

Wrong.
It only removes the public bailout.
The candidate search can still decide the current order is already best or tied.

### Misread 2: this is a generic "fix dependencies" pass

Too broad.
It preserves dependency order, but it still uses the same profitability-oriented candidate search as `reorder-globals`.

### Misread 3: this is the production late-tail pass

Wrong.
The canonical production late-tail pass is still ordinary `reorder-globals`.
The sibling is the small-module/test/internal-fixup variant.

## Starshine-local caveat

These WAT shapes describe Binaryen behavior. In Starshine, the pass name is currently boundary-only and explicit requests are rejected. A future local implementation must also repair numeric `GlobalIdx` references after reordering; see [`./starshine-strategy.md`](./starshine-strategy.md).

## Sources

- [`../../../raw/binaryen/2026-04-25-reorder-globals-always-primary-sources.md`](../../../raw/binaryen/2026-04-25-reorder-globals-always-primary-sources.md)
- [`../../../raw/research/0336-2026-04-25-reorder-globals-always-source-bridge.md`](../../../raw/research/0336-2026-04-25-reorder-globals-always-source-bridge.md)
- [`../../../raw/research/0188-2026-04-21-reorder-globals-always-binaryen-research.md`](../../../raw/research/0188-2026-04-21-reorder-globals-always-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals-real.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>

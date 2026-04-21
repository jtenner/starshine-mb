---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0137-2026-04-20-memory-packing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./segment-op-rewrites-and-traps.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `memory-packing` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen's `memory-packing` pass.

## Read this page with one mental model

Binaryen `memory-packing` is trying to prove:

- these bytes are zero often enough to be worth omitting,
- the surrounding segment layout is predictable enough,
- every instruction that uses the original segment can still behave the same after rewriting,
- and any startup or runtime traps are still preserved.

If that proof fails, the pass keeps the original segment intact.

## Quick glossary

- **active segment**: written during module instantiation
- **passive segment**: later read by `memory.init` or similar instructions
- **zero run**: contiguous span of `\00` bytes
- **split segment**: one surviving nonzero subrange emitted as a new data segment
- **drop-state global**: synthetic mutable global used to preserve dropped-segment trap behavior
- **trampling**: one active segment overwriting bytes written by another

## Positive family 1: active segment with a large trailing zero run

Before:

```wat
(memory 1)
(data (i32.const 100) "ABC\00\00\00\00\00\00\00\00\00")
```

After, conceptually:

```wat
(memory 1)
(data (i32.const 100) "ABC")
```

Why this is safe:

- active memory starts zero-initialized
- the omitted bytes were already zero
- no passive runtime user needs the original bytes later

## Positive family 2: active segment with a large leading zero run

Before:

```wat
(memory 1)
(data (i32.const 100) "\00\00\00\00\00\00\00\00ABC")
```

After, conceptually:

```wat
(memory 1)
(data (i32.const 108) "ABC")
```

The key point is:

- the surviving nonzero range moves the emitted offset forward

## Positive family 3: active segment with a large middle zero run

Before:

```wat
(memory 1)
(data (i32.const 100) "ABC\00\00\00\00\00\00\00\00XYZ")
```

After, conceptually:

```wat
(memory 1)
(data $seg   (i32.const 100) "ABC")
(data $seg.1 (i32.const 111) "XYZ")
```

This is the most obvious “packing” shape.

## Positive family 4: passive segment rewritten into `memory.init` plus `memory.fill`

Before:

```wat
(memory 1)
(data $d "ABC\00\00\00XYZ")
(func
  (memory.init $d
    (i32.const 0)
    (i32.const 0)
    (i32.const 9))
  (data.drop $d))
```

After, conceptually:

```wat
(memory 1)
(data $d "ABC")
(data $d.1 "XYZ")
(func
  (block
    (memory.init $d   (i32.const 0) (i32.const 0) (i32.const 3))
    (memory.fill      (i32.const 3) (i32.const 0) (i32.const 3))
    (memory.init $d.1 (i32.const 6) (i32.const 0) (i32.const 3)))
  (block
    (data.drop $d)
    (data.drop $d.1)))
```

Important nuance:

- this is why upstream `memory-packing` is not just a segment-only transform

## Positive family 5: leading zeroes in a passive segment

Before:

```wat
(data $d "\00\00\00HELLO")
(memory.init $d ... 8)
```

After, conceptually:

```wat
(if (global.get $__mem_segment_drop_state)
  (then unreachable))
(memory.fill ... 3)
(memory.init $d ... 5)
```

Why the explicit `if` appears:

- the transformed sequence starts with `memory.fill`
- `memory.fill` does not trap on dropped segments
- the original `memory.init` would have

So Binaryen adds an explicit dropped-state check.

## Positive family 6: dynamic destination gets a temp local

Before:

```wat
(func (param $dest i32)
  (memory.init $d
    (local.get $dest)
    (i32.const 0)
    (i32.const 9)))
```

After, conceptually:

```wat
(func (param $dest i32) (local $tmp i32)
  (local.set $tmp (local.get $dest))
  ...
  (memory.fill (local.get $tmp) ...)
  (memory.init $d.1 (i32.add (local.get $tmp) (i32.const 6)) ...))
```

This is not an optimization gimmick.
It is how the pass preserves correct repeated destination use after splitting.

## Positive family 7: imported memory only with `--zero-filled-memory`

Before:

```wat
(import "env" "memory" (memory 1 1))
(data (i32.const 1024) "x")
(data (i32.const 1023) "\00")
```

With `--zero-filled-memory`, Binaryen can safely remove the active zero-only segment and keep just the nonzero write.

Without that flag, the zero write must stay.

## Positive family 8: startup-trapping active segment keeps only the top byte

Before:

```wat
(memory 1 2)
(data (i32.const 65535) "\00\00")
```

After, conceptually:

```wat
(memory 1 2)
(data (i32.const 65536) "\00")
```

The important rule is:

- Binaryen keeps just enough of the segment to preserve the same startup trap

## Positive family 9: memory64 shapes

Before:

```wat
(memory i64 1 1)
(data "...big zero-heavy bytes...")
(func
  (memory.init 0
    (i64.const 0)
    (i32.const 0)
    (i32.const 127)))
```

After, conceptually:

- split passive segments still work
- destination arithmetic uses i64
- size/offset slice arithmetic remains correct

A beginner should remember:

- `memory-packing` is not accidentally i32-only
- but some segment-offset and `memory.init` immediates still need unsigned i32 interpretation even in memory64 contexts

## Positive family 10: passive segment with only `data.drop` users disappears

Before:

```wat
(data $d "dead\00\00\00")
(func
  (data.drop $d))
```

After, conceptually:

```wat
(func
  (nop))
```

The passive segment can be removed because no real read remains.

## Negative family 1: overlapping active segments

Before:

```wat
(memory 1)
(data (i32.const 1024) "x")
(data (i32.const 1024) "\00")
```

Why this blocks optimization:

- the second active segment deliberately overwrites the first
- the zero byte is semantically observable as a later startup write
- Binaryen therefore gives up on the module-level optimization

## Negative family 2: dynamic active offset when multiple active segments exist

Before:

```wat
(import "env" "base" (global i32))
(memory 1)
(data (i32.const 1024) "x")
(data (global.get 0) "\00")
```

Why this blocks optimization:

- Binaryen cannot know whether the dynamic segment will trample the first one
- the safe answer is to keep both segments intact

## Negative family 3: imported memory without `--zero-filled-memory`

Before:

```wat
(import "env" "memory" (memory 1 1))
(data (i32.const 1024) "x")
(data (i32.const 2048) "\00")
```

Why this blocks optimization:

- Binaryen cannot assume the host already provided zero bytes everywhere else
- dropping the explicit zero write could change behavior

## Negative family 4: tiny zero runs are not always worth splitting

Before:

```wat
(data $d "few\00\00\00zeroes")
```

Why this may stay unchanged:

- splitting would add more segment/op overhead than it saves
- profitability, not just legality, matters

## Negative family 5: `__llvm*` segments

Conceptually:

```wat
(data $__llvm_covfun "...")
```

Why this blocks splitting:

- downstream LLVM coverage tools expect exact segment contents and naming/layout assumptions
- Binaryen conservatively leaves those segments intact

## Negative family 6: empty segments

Before:

```wat
(data (i32.const 4066) "")
```

Why this is left alone:

- it may still have startup-trap or indexing consequences
- upstream leaves it for later cleanup passes such as `remove-unused-module-elements`

## Negative family 7: passive segment with dynamic source slice

Before:

```wat
(data $d "ABC\00\00XYZ")
(func (param $off i32)
  (memory.init $d
    (i32.const 0)
    (local.get $off)
    (i32.const 9)))
```

Why this blocks splitting:

- the pass only rewrites passive `memory.init` users when offset and size are constant
- dynamic source slicing would need more complex runtime logic

## Negative family 8: GC `array.new_data` / `array.init_data` users

Before:

```wat
(type $array (array i8))
(data $d "optimize\00\00\00me")
(func (result (ref $array))
  (array.new_data $array $d
    (i32.const 0)
    (i32.const 8)))
```

Why this blocks splitting today:

- upstream sees the GC user
- but does not rewrite it to a split-segment sequence here
- so the safe answer is to keep the segment intact

## Negative family 9: too many resulting segments

Before, conceptually:

```text
many alternating single-byte nonzero runs and long zero runs
```

Why Binaryen may stop splitting fully:

- too many split segments would exceed the module limit
- the pass merges the remaining ranges back together instead of emitting an invalid module

This is a validity boundary, not a semantic one.

## Negative family 10: zero-size `memory.init` is not dead by default

Before:

```wat
(memory.init $d
  (i32.const 13)
  (i32.const 0)
  (i32.const 0))
```

Why this is not simply erased:

- the destination bounds check can still trap
- the dropped-segment state can still matter

## Negative family 11: high-bit i32 immediates in memory64 contexts

A beginner might misread this as a negative signed number:

```wat
(memory.init $d
  (i64.const 0)
  (i32.const 0x80000000)
  (i32.const 1))
```

But Binaryen treats that offset as the large unsigned byte position `2147483648`.

Why this matters:

- sign-extending it would produce the wrong trap decision and wrong rewrite

## Decision-shape note: active and passive thresholds differ

Two visually similar zero runs can produce different results depending on whether the segment is:

- active
- passive with one or more `memory.init` / `data.drop` users

That is because passive splitting has extra emitted-op overhead while active splitting mostly changes only segment bytes.

## What this pass does **not** mean

These are useful non-goals to keep explicit:

- generic memory-content deduplication
- multimemory layout optimization
- full symbolic reasoning about runtime-overlapping active segments
- rewriting of GC data-segment users today
- deletion of all zero bytes unconditionally
- erasure of all zero-size `memory.init` operations

## Scheduler interaction to remember

`memory-packing` is intentionally early and module-scoped.
It sits before `once-reduction` and `global-refining`, and it does not participate in later per-function reruns.

So its job is not to solve every memory optimization story.
Its job is to clean up data-segment layout and passive-segment use sites early enough that later module and function passes can operate on a smaller, cleaner module.

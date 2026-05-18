---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md
  - ../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md
  - ../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./linear-traces-read-only-to-write-and-reruns.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../remove-unused-module-elements/index.md
---

# `simplify-globals-optimizing` WAT and IR shape guide

This page is the beginner-friendly shape catalog for Binaryen `simplify-globals-optimizing`, anchored to the primary-source manifests in [`../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md) and [`../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md).

The main question to keep asking is:

- “is Binaryen removing fake global state, or proving a global value in a context where that proof is still cheap and safe?”

## Quick orientation

The pass has three broad rewrite zones:

| Zone | Typical shape | Main safety idea |
| --- | --- | --- |
| Global-init folding | one global initializer used once by another global initializer | module instantiation happens once |
| Global-state cleanup | `global.set` writes whose value never matters | keep operand effects, delete fake state |
| Value propagation | later init/offsets or simple runtime traces reading known values | startup order or cheap linear-trace proof |

## Positive shapes Binaryen really rewrites

## 1. Single-use global initializer copied into one later global initializer

Before:

```wat
(global $single-use anyref
  (struct.new $A
    (ref.i31 (i32.const 42))
  )
)
(global $other anyref
  (global.get $single-use)
)
```

After conceptually:

```wat
(global $single-use anyref
  (struct.new $A
    (ref.i31 (i32.const 42))
  )
)
(global $other anyref
  (struct.new $A
    (ref.i31 (i32.const 42))
  )
)
```

Why it works:

- the source global has exactly one read
- the use is in another global initializer
- the initializer code still runs only once overall

## 2. Immutable copy chain collapsed to the earliest compatible ancestor

Before:

```wat
(import "a" "b" (global $g1 i32))
(global $g2 i32 (global.get $g1))
(global $g3 i32 (global.get $g2))
(func
  (drop (global.get $g3))
)
```

After conceptually:

```wat
(import "a" "b" (global $g1 i32))
(global $g2 i32 (global.get $g1))
(global $g3 i32 (global.get $g1))
(func
  (drop (global.get $g1))
)
```

Why it works:

- each copied global is immutable
- Binaryen can chase the chain back to the earliest immutable ancestor
- the use type still matches exactly

## 3. Later global initializer sees an earlier known constant

Before:

```wat
(global $a i32 (i32.const 42))
(global $b i32 (global.get $a))
(global $c i32
  (i32.add
    (global.get $b)
    (global.get $a)
  )
)
```

After conceptually:

```wat
(global $a i32 (i32.const 42))
(global $b i32 (i32.const 42))
(global $c i32
  (i32.add
    (i32.const 42)
    (i32.const 42)
  )
)
```

Why it works:

- Binaryen is still in startup order here
- no runtime writes have happened yet

## 4. Segment offset reads replaced during startup propagation

Before:

```wat
(global $defined i32 (i32.const 42))
(elem (global.get $defined) func $f)
(data (global.get $defined) "abc")
```

After conceptually:

```wat
(global $defined i32 (i32.const 42))
(elem (i32.const 42) func $f)
(data (i32.const 42) "abc")
```

Why it works:

- segment offsets are part of instantiation-time init logic too
- Binaryen handles nested `global.get`s there just like in later global initializers

## 5. Dead `global.set` becomes `drop(value)` when the global is never read

Before:

```wat
(global $g (mut i32) (i32.const 0))
(func
  (global.set $g
    (call $expensive)
  )
)
```

After conceptually:

```wat
(global $g i32 (i32.const 0))
(func
  (drop
    (call $expensive)
  )
)
```

Why it works:

- the stored value is never observed
- the operand may still have effects, so Binaryen keeps it as `drop(...)`
- the global itself can now become effectively immutable

## 6. Write of the initializer value becomes `drop(value)`

Before:

```wat
(global $g (mut i32) (i32.const 0))
(func
  (global.set $g (i32.const 0))
)
```

After conceptually:

```wat
(global $g i32 (i32.const 0))
(func
  (drop (i32.const 0))
)
```

Why it works:

- Binaryen proved the write does not change state relative to the initializer

## 7. `read-only-to-write` self-guard collapses away the stateful part

Before:

```wat
(global $once (mut i32) (i32.const 0))
(func
  (if
    (global.get $once)
    (then
      (global.set $once (i32.const 1))
    )
  )
)
```

After conceptually:

```wat
(global $once i32 (i32.const 0))
(func
  (if
    (i32.const 0)
    (then
      (drop (i32.const 1))
    )
  )
)
```

Why it works:

- the global read only decided whether to write that same global
- nothing else observable depended on that read

### Block-wrapped condition variation

A transparent value-producing block can provide the same self-guard condition:

```wat
(global $once (mut i32) (i32.const 0))
(func
  (if
    (block (result i32)
      (global.get $once)
    )
    (then
      (global.set $once (i32.const 1))
    )
  )
)
```

The current Starshine SGO subset treats that single yielded `global.get` as the same read-only-to-write condition when the adjacent `if` writes one constant to the same global.

## 8. Whole-function `if return; set` family collapses the set to a drop

Before:

```wat
(global $once (mut i32) (i32.const 0))
(func $clinit
  (if
    (global.get $once)
    (then
      (return)
    )
  )
  (global.set $once (i32.const 1))
)
```

After conceptually:

```wat
(global $once i32 (i32.const 0))
(func $clinit
  (if
    (i32.const 0)
    (then
      (return)
    )
  )
  (drop (i32.const 1))
)
```

Why it works:

- Binaryen has a special narrow whole-function matcher for exactly this shape

## 9. Runtime code reads replaced after a known constant `global.set`

Before:

```wat
(global $g (mut i32) (i32.const 0))
(func
  (global.set $g (i32.const 10))
  (drop (global.get $g))
)
```

After conceptually:

```wat
(global $g (mut i32) (i32.const 0))
(func
  (global.set $g (i32.const 10))
  (drop (i32.const 10))
)
```

Why it works:

- Binaryen tracks a cheap current-value map along the current linear trace

## 10. Some dominated adjacent blocks are included in that same runtime proof

Before:

```wat
(global.set $g (i32.const 10))
(if
  (i32.const 0)
  (then
    (block
      (drop (global.get $g))
    )
  )
)
```

After conceptually:

```wat
(global.set $g (i32.const 10))
(if
  (i32.const 0)
  (then
    (block
      (drop (i32.const 10))
    )
  )
)
```

Why it works:

- `LinearExecutionWalker` connects some adjacent dominated blocks cheaply

## 11. GC / reference-type constant replacement can be more refined than the old `global.get`

Before:

```wat
(global $f (mut funcref) (ref.func $func))
(func
  (drop
    (ref.cast (ref null $A)
      (global.get $f)
    )
  )
)
```

After conceptually:

```wat
(global $f (mut funcref) (ref.func $func))
(func
  (drop
    (ref.cast (ref $A)
      (ref.func $func)
    )
  )
)
```

Why it works:

- replacing the global read may reveal a more precise reference type
- Binaryen refinalizes the function when replacement changes types

## Negative or bailout shapes Binaryen deliberately preserves

## 1. The single use is in function code, not another global initializer

Before:

```wat
(global $single-use anyref (struct.new $A ...))
(func
  (drop (global.get $single-use))
)
```

Preserved because:

- function code may execute more than once
- copying the initializer there could change generative identity or repetition count

## 2. The global has more than one use

Before:

```wat
(global $single-use anyref (struct.new $A ...))
(global $a anyref (global.get $single-use))
(global $b anyref (global.get $single-use))
```

Preserved because:

- the single-use fold is intentionally only for exactly one read

## 3. Imported or exported globals block destructive cleanup families

Before:

```wat
(import "env" "g" (global $g i32))
;; or
(export "g" (global $g))
```

Preserved because:

- outside observers may still depend on the boundary
- Binaryen will not erase or silently change that state story here

## 4. A call breaks runtime current-value propagation

Before:

```wat
(global.set $g (i32.const 10))
(call $maybe_sets_globals)
(drop (global.get $g))
```

Preserved because:

- calls clear the current-value map in runtime propagation

## 5. Nonlinear control breaks runtime current-value propagation

Before:

```wat
(global.set $g (i32.const 10))
(loop $L
  ...
)
(drop (global.get $g))
```

Preserved because:

- the cheap linear-trace model is intentionally invalidated by nonlinear control

## 6. `if` with `else` is not a `read-only-to-write` match

Before:

```wat
(if
  (global.get $g)
  (then
    (global.set $g (i32.const 1))
  )
  (else
    (nop)
  )
)
```

Preserved because:

- the matcher explicitly rejects `if-else`

## 7. Extra reads of the same global block `read-only-to-write`

Before:

```wat
(if
  (global.get $g)
  (then
    (global.set $g (i32.const 1))
  )
)
(drop (global.get $g))
```

Preserved because:

- the global is now read for more than “should I write `$g`?”

## 8. Condition side effects are fine only if the global’s value does not steer them dangerously

Negative example:

```wat
(if
  (if (result i32)
    (global.get $g)
    (then (call $foo))
    (else (i32.const 1))
  )
  (then
    (global.set $g (i32.const 1))
  )
)
```

Preserved because:

- `$g` decides whether `foo()` runs

Positive contrast:

```wat
(if
  (if (result i32)
    (call $foo)
    (then (i32.const 1))
    (else (global.get $g))
  )
  (then
    (global.set $g (i32.const 1))
  )
)
```

Optimized because:

- the side effect exists, but `$g` does not decide whether it happens

## 9. Calls with computed effects do not count as actual `global.get` / `global.set` nodes for `read-only-to-write`

Negative example:

```wat
(if
  (block (result i32)
    (drop (call $get))
    (i32.const 1)
  )
  (then
    (global.set $g (i32.const 0))
  )
)
```

Preserved because:

- Binaryen insists on matching real AST `GlobalGet` / `GlobalSet` nodes for this family
- effect summaries are used for invalidation and safety, not as substitutes for the matcher

## 10. Exact type mismatch blocks copy-chain canonicalization

Before:

```wat
(global $a (ref $struct) (struct.new_default $struct))
(global $c (ref null $struct) (global.get $a))
(func
  (global.get $c)
)
```

Preserved because:

- Binaryen only rewrites copy chains when the ancestor type matches the current use exactly
- the source has a TODO for a more aggressive refinalizing version, but `version_129` does not do that yet

## 11. Exported generative global stays separate

Before:

```wat
(global $A (ref $struct) (struct.new_default $struct))
(global $B (ref $struct) (global.get $A))
(export "A" (global $A))
```

Preserved because:

- duplicating or collapsing a generative exported initializer can change observable identity

## 12. The whole-function `if return; set` family is very exact

Before:

```wat
(func $clinit
  (if (global.get $once)
    (then (return))
  )
  (global.set $once (i32.const 1))
  (nop)
)
```

Preserved because:

- the body now has too many elements for the exact matcher

## Interaction shapes worth remembering

## 1. `drop(const)` debris is expected after simplify-globals

When the pass removes writes or collapses self-guarded state, it often leaves behind:

```wat
(drop (i32.const 1))
```

That is not a bug. It preserves operand evaluation until later cleanup removes the now-obvious dead work.

## 2. The optimizing variant exists to clean up that debris immediately

If a function changed, `simplify-globals-optimizing` reruns the default function optimization pipeline on that function.

So a positive mental model is:

- simplify-globals creates new constants and drops
- nested function cleanup cashes in on them right away

## 3. But dead globals themselves are mostly for later module cleanup

The pass often stops after making a global:

- immutable
- unread
- or otherwise pointless

The later top-level `remove-unused-module-elements` pass is what actually removes many of those now-dead globals from the module.

## Easy mental checklist for future Starshine work

For a concrete future local test ladder, pair this shape catalog with [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

When deciding whether a shape should rewrite, ask:

1. Is this still module-init time, or already runtime code?
2. If runtime, is the current execution story still cheap and linear enough?
3. If erasing a global state family, is the read really only “to decide whether to write the same global”?
4. Are there actual AST `global.get` / `global.set` nodes, not just effect summaries?
5. Would the rewrite need type repair or exact-type gating?
6. Is later cleanup expected to finish the story?

That checklist matches the actual `version_129` source much better than “constant globals good, mutable globals bad.”

## Sources

- [`../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md)
- [`../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md`](../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md)
- [`../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md`](../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md)

---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md
  - ../../../raw/research/0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md
  - ../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/licm.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./effects-loops-and-hoisting-rules.md
  - ./starshine-strategy.md
---

# WAT shape catalog for `loop-invariant-code-motion`

This page catalogs the main shape families beginners should look for when reading Binaryen LICM output.
The 2026-04-24 source recheck corrected the older page: reviewed Binaryen `version_129` LICM moves eligible **none-typed statements** before the loop and leaves `nop`s behind; it does not synthesize fresh temp locals for arbitrary value subtrees.

## Positive family 1: simple dropped work at loop entry

Before:

```wat
(func $f (param $x i32)
  (loop $L
    (drop
      (i32.add
        (local.get $x)
        (i32.const 1)))))
```

LICM-style shape:

```wat
(func $f (param $x i32)
  (block
    (drop
      (i32.add
        (local.get $x)
        (i32.const 1)))
    (loop $L
      (nop))))
```

Meaning:

- the whole `drop` statement has type `none`,
- it is at the unconditional loop entrance,
- its local read is not loop-carried,
- Binaryen moves the statement before the loop and leaves `nop` behind.

## Positive family 2: invariant `local.set` at loop entry

Before:

```wat
(func $f (param $x i32) (local $t i32)
  (loop $L
    (local.set $t
      (i32.add (local.get $x) (i32.const 1)))
    (drop (local.get $t))))
```

Possible LICM-style shape:

```wat
(func $f (param $x i32) (local $t i32)
  (block
    (local.set $t
      (i32.add (local.get $x) (i32.const 1)))
    (loop $L
      (nop)
      (drop (local.get $t)))))
```

Meaning:

- moving the `local.set` is only safe when `$x` is not set inside the loop,
- no other set to `$t` remains in the loop,
- and the RHS has no blocking effects.

## Positive family 3: nested-loop exposure

Before:

```wat
(loop $outer
  (loop $inner
    (drop (i32.add (local.get $x) (i32.const 1)))))
```

Possible story:

1. The statement can move out of `$inner`.
2. After that, it may be visible around `$outer` as the walker continues.

This is the source-backed nested-loop exposure behavior.
Do not confuse it with arbitrary child-then-parent temp-local hoisting.

## Positive family 4: flattening-enabled statement motion

Before a separate flattening-style preparation, candidate work may be hidden inside larger structure:

```wat
(loop $L
  (if (local.get $cond)
    (then
      (drop (i32.add (local.get $x) (i32.const 1))))))
```

After a different pass exposes independent none-typed entry statements, LICM may have more useful candidates.
The important boundary is that LICM consumes such exposed statements; it does not perform the full flattening itself.

## Bailout family 1: hidden under conditional control

```wat
(loop $L
  (if (local.get $cond)
    (then
      (drop (i32.add (local.get $x) (i32.const 1))))))
```

Why it stays in ordinary LICM shape:

- the `drop` is not an unconditional loop-entry statement,
- moving it before the loop would execute it on paths where the `if` arm might not run.

## Bailout family 2: statement after control transfer

```wat
(loop $L
  (br_if $L (local.get $cond))
  (drop (i32.add (local.get $x) (i32.const 1))))
```

Why it stays:

- the entrance scan stops at control-transfer effects,
- the later statement is not considered by this pass.

## Bailout family 3: loop-carried local dependency

```wat
(loop $L
  (local.set $x (i32.add (local.get $x) (i32.const 1)))
  (drop (i32.mul (local.get $x) (i32.const 2))))
```

Why it stays:

- the `drop` reads `$x`,
- `$x` depends on a `local.set` inside the loop,
- `LazyLocalGraph`-style dependency analysis blocks the move.

## Bailout family 4: competing local sets

```wat
(loop $L
  (local.set $x (i32.const 1))
  (local.set $x (i32.const 2)))
```

Why it stays:

- moving just one set while another remains in the loop can change the local timeline,
- Binaryen counts loop-local sets and rejects this case.

## Bailout family 5: memory-sensitive operation

```wat
(loop $L
  (i32.store (local.get $p) (local.get $v)))
```

Why it stays:

- stores are excluded from the interesting candidate surface,
- mutable-state effects are conservative motion blockers.

## Bailout family 6: call at loop entry

```wat
(loop $L
  (call $helper))
```

Why it stays:

- calls are excluded by the candidate filter,
- they can carry observable effects.

## Bailout family 7: trap timing hazard

```wat
(loop $L
  (drop (i32.div_s (local.get $x) (local.get $y))))
```

Why it may stay:

- moving trap-capable work before the loop can change when, or whether, the trap occurs,
- Binaryen rejects trap motion in the presence of relevant mutable-state hazards.

## Mixed family: first statement moves, later statement stays

Before:

```wat
(loop $L
  (drop (i32.add (local.get $x) (i32.const 1)))
  (call $helper)
  (drop (i32.add (local.get $y) (i32.const 2))))
```

Possible outcome:

- the first `drop` can move,
- the `call` stays,
- the scan stops at or rejects the call boundary,
- the later `drop` stays even if it looks otherwise pure.

This mixed case is important because it shows LICM is prefix-oriented, not a whole-loop search for every pure expression.

## What the pass is not trying to do

LICM is not trying to:

- flatten control flow,
- fold constants like `precompute`,
- find equal nearby trees like `local-cse`,
- sink code deeper like `code-pushing`,
- rewrite whole local webs like `simplify-locals`,
- or cache arbitrary invariant values in fresh locals.

## Practical reading rule

When reading candidate LICM output, ask these questions in order:

1. is the candidate a none-typed statement?
2. is it in the unconditional loop-entry prefix before control transfer?
3. would computing it before the loop preserve global state, exception behavior, mutable state, and trap timing?
4. do its `local.get`s avoid loop-local `local.set`s?
5. if it is a `local.set`, is it the only set to that local in the loop?

If the answer to any of those becomes “no,” expect a bailout.

## Sources

- [`../../../raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md`](../../../raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md)
- [`../../../raw/research/0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md`](../../../raw/research/0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md)
- [`../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md`](../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/licm.wast>

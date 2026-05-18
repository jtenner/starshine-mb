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
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../dae-optimizing/index.md
  - ../inlining-optimizing/index.md
---

# `simplify-globals-optimizing`: linear traces, `read-only-to-write`, and reruns

This page focuses on the parts of Binaryen `simplify-globals-optimizing` that are easiest to misunderstand.
It is now anchored to the committed primary-source manifest in [`../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md):

- why startup-time propagation is broader than runtime code propagation
- what `read-only-to-write` really means in the source
- why actual AST `global.get` / `global.set` nodes matter more than effect summaries there
- why the optimizing rerun is part of the real pass contract

## The big beginner warning

If you summarize the pass as:

- “constant-fold global reads”

you will miss most of the implementation.

The real story is closer to:

- “use whole-module global traffic facts to remove fake state, collapse easy one-time indirections, and propagate only the values Binaryen can still justify safely in the current context.”

## 1. Startup-time propagation and runtime propagation are different algorithms

This is the first major mental-model split.

## Startup-time propagation: later globals and segment offsets

When Binaryen is rewriting:

- later global initializers
- element-segment offsets
- data-segment offsets

it is still in module-instantiation order.

That means no runtime code has executed yet.
So if an earlier global currently has a known constant value, Binaryen can substitute that value into later init expressions even if the global is mutable at runtime.

Safe beginner phrasing:

- “mutable later” does not stop “known right now during startup.”

That is why this shape is positive:

```wat
(global $a (mut i32) (i32.const 42))
(global $b i32 (global.get $a))
```

At global-init time, `$a` is still definitely `42`, so `$b` can become `i32.const 42`.

## Runtime propagation: only when the current trace is still simple

Inside function code, Binaryen cannot make that same broad assumption.

The runtime phase starts from two narrower sources of truth:

- globally constant globals
- or globals given a known constant earlier in the **current linear trace**

So this shape is positive:

```wat
(global.set $g (i32.const 10))
(drop (global.get $g))
```

but only until a barrier appears.

## 2. Calls and nonlinear control are the major runtime barriers

`ConstantGlobalApplier` deliberately uses a cheap current-trace model, not a full CFG proof.

It forgets tracked current values when it sees:

- a call
- nonlinear control
- a write to a tracked global

That means this is a negative family:

```wat
(global.set $g (i32.const 10))
(call $maybe_changes_globals)
(drop (global.get $g))
```

Even if the call often does not write `$g`, Binaryen clears its current-value map there.

The `simplify-globals-dominance.wast` test makes this explicit: a dominated read before the call can optimize, the read after the call does not.

## 3. `connectAdjacentBlocks = true` is helpful, but not magic

The runtime walker enables adjacent-block connection.

That lets Binaryen handle some common “dominated right after this” shapes cheaply, like:

```wat
(global.set $g (i32.const 10))
(if (i32.const 0)
  (then
    (drop (global.get $g))
  )
)
```

But the pass still does **not** become a full dominator-tree analysis.

The shipped dominance test includes an explicit TODO for a dominated `else` case that Binaryen does not optimize yet.

So a future port should preserve the current narrow adjacency-based win rather than silently widening it into a different analysis contract.

## 4. `read-only-to-write` is about fake state, not just matching names

A good beginner summary of the source rule is:

- a global qualifies only when Binaryen can prove the program reads it solely to decide whether to write that same global, and nothing else important depends on that read.

This is positive:

```wat
(if
  (global.get $once)
  (then
    (global.set $once (i32.const 1))
  )
)
```

This is **not** enough by itself:

- same global name appears in condition and body

The source also checks effects, actual AST nodes, and value flow.

## 5. The body must be “just write the global”

The `read-only-to-write` matcher requires the body code to have:

- exactly one written global effect
- no other remaining effects after clearing that one global write from the effect set

So these are negative families:

- the body also calls a function
- the body writes memory
- the body writes another global
- the body throws

But the body may still contain side-effect-free wrappers around the write, like a `block` with `nop` plus the `global.set`.

That is why this can still optimize:

```wat
(if
  (i32.eqz (global.get $once))
  (then
    (block
      (nop)
      (global.set $once (i32.const 1))
    )
  )
)
```

As of the 2026-05-18 Starshine slices, the local SGO matcher covers adjacent `i32.eqz`, bidirectional compare-const, nested block-condition, block-wrapped condition-read forms including `i32.eqz`, no-op const/drop prefixes before block-wrapped condition reads, this transparent `nop` / void-`block` body family, and no-op const/drop prefixes before the single constant write for self guards, but still does not cover the broader whole-function or iterative `read-only-to-write` families below.

## 6. Actual AST `global.get` / `global.set` nodes matter more than effect summaries

This is one of the biggest source-level subtleties.

Binaryen does use computed function effects elsewhere in the pass, but for `read-only-to-write` it still insists on:

- an actual `GlobalGet` node in the condition
- an actual `GlobalSet` node in the body

So this is a negative family:

```wat
(if
  (block (result i32)
    (drop (call $getter))
    (i32.const 1)
  )
  (then
    (global.set $g (i32.const 0))
  )
)
```

Even if Binaryen already knows `$getter` reads `$g`, that is **not** the same as seeing an actual `global.get $g` in the condition here.

The same applies to body writes through calls.

That distinction is deliberate. The pass wants whole-program counting over concrete read/write sites before it erases the global state itself.

## 7. Value flow into side effects is the real danger

The pass does not reject every condition with side effects.

It rejects when the **global’s value** can determine side-effectful behavior dangerously.

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

Here `$g` decides whether `foo()` runs, so the read is observable for more than “should I write `$g`?”

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

Now the side effect exists, but `$g` does not choose whether `foo()` runs. Its value only flows safely out through the final condition result.

That is why the source needs an upward value-flow walk instead of just a flat “side effects yes/no” check.

## 8. Nested appearances of the same pattern are allowed

The matcher contains an explicit carveout for another appearance of the same `read-only-to-write` pattern nested inside the current one.

That is why multi-layer examples like this can still optimize:

```wat
(if
  (block (result i32)
    (if
      (i32.eqz (global.get $once))
      (then
        (global.set $once (i32.const 1))
      )
    )
    (i32.eq (global.get $once) (i32.const 0))
  )
  (then
    (global.set $once (i32.const 1))
  )
)
```

But if the nested form stops being that exact safe family, the optimization stops too.

The test suite has explicit near-miss negatives for:

- nested `if` with `else`
- extra unrelated `global.get`
- extra trailing code that breaks the exact whole-function shape

## 9. The whole-function `if return; set` family is intentionally narrow

Binaryen also recognizes this exact shape:

```wat
(block
  (if
    (global.get $once)
    (then
      (return)
    )
  )
  (global.set $once (i32.const 1))
)
```

Beginner takeaway:

- this is not a general CFG proof that “the set is guarded by an early return”
- it is an exact narrow body pattern

The function body must be exactly two elements long in the direct form. Binaryen also accepts the same guard when the condition is `global.get; i32.eqz`, `global.get; const; i32.eq/i32.ne`, or `const; global.get; i32.eq/i32.ne`. Add a trailing `nop`, and Binaryen preserves the original shape.

As of the 2026-05-18 follow-up slices, Starshine covers the exact, `i32.eqz`, and bidirectional compare-const `if return; set` family and keeps a focused trailing-`nop` negative so it does not widen into a broader CFG proof by accident.

## 10. The optimizing rerun is part of the real pass contract

The biggest scheduler lesson is this:

- the optimizing variant is not just “simplify-globals but nicer”
- it is simplify-globals plus a deliberately chosen nested cleanup replay

When a function changes because:

- a `global.get` became a constant, or
- a `global.set` became `drop(value)`

Binaryen builds a nested `PassRunner` from the parent runner and calls:

- `addDefaultFunctionOptimizationPasses()`
- `runOnFunction(curr)`

So the new cleanup opportunities are intentionally cashed in immediately.

## What the rerun can clean up

After simplify-globals changes a function, the touched function may contain fresh debris such as:

- `drop(i32.const ...)`
- dead branches after a condition became constant
- dead locals after values stopped flowing from globals
- simpler instruction trees after a copied constant or `ref.func` arrived

The nested replay is how Binaryen turns those local wins into the final intended function body.

## 11. This rerun is smaller than the after-inlining helper

This is the crucial difference from the newly documented late boundary passes nearby.

`dae-optimizing` and `inlining-optimizing` use a helper that prepends:

- `precompute-propagate`

before replaying the default function optimization pipeline.

`simplify-globals-optimizing` does **not** do that.

It reruns only:

- the ordinary default function optimization pipeline

That is why the repo’s old maintained no-DWARF note was right to separate this pass’s nested shape from the after-inlining helper family.

## 12. Why the saved `-O4z` debug log still matters

The saved log does not reveal the exact inner pass names here, but it does prove that top-level `simplify-globals-optimizing` expands into nested work before the next top-level `remove-unused-module-elements`.

Repo-local counting on the saved log finds:

- `3` nested pass batches

That is enough to keep the scheduler lesson durable:

- this pass belongs in the tracker as a boundary/module pass with nested reruns,
- not just as “the last constant-global cleanup before RUME.”

## 13. Good mental model for future Starshine work

If you need one durable porting mental model, use this:

- simplify-globals rewrites global state only when Binaryen still has a simple enough proof,
- startup and runtime propagation use different proof styles,
- `read-only-to-write` is a real whole-program safety matcher,
- and the optimizing variant expects ordinary function cleanup to run immediately afterward.

That is what the implementation really preserves.

## Sources

- [`../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md)
- [`../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md`](../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md)
- [`../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md`](../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md)

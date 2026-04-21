---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0136-2026-04-20-pick-load-signs-binaryen-research.md
  - ../../../raw/research/0228-2026-04-21-pick-load-signs-implementation-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./parity.md
  - ./starshine-hot-ir-strategy.md
---

# `pick-load-signs`: implementation structure and tests

This page is the compact source-confirmed map for Binaryen `version_129` `pick-load-signs`.

Its main job is to answer two practical questions:

1. which upstream files really own the pass contract?
2. which shipped tests prove that contract, and which nearby tests belong to neighboring passes instead?

## Main owner files

## `src/passes/PickLoadSigns.cpp`

This is the real owner file.

It contains the entire visible pass algorithm:

- the `Usage` record per local,
- candidate discovery from exact non-tee `local.set(load ...)` producers,
- parent/grandparent use inspection with `ExpressionStackWalker`,
- final signed-vs-unsigned load flipping,
- and the atomic-load bailout.

For this pass, that fact matters because the implementation is more self-contained than the pass name suggests.
There is no big separate solver or hidden load-analysis subsystem behind it.

## `src/ir/properties.h`

This file is the most important helper owner.

`PickLoadSigns.cpp` delegates its key meaning tests to `properties.h` helpers:

- `getSignExtValue(...)`
- `getSignExtBits(...)`
- `getZeroExtValue(...)`
- `getZeroExtBits(...)`

That helper split is why the pass is effectively i32-only in upstream `version_129` even though its public name sounds broader.
The pass logic itself is small partly because the sign/zero-extension recognition details live here.

## `src/passes/pass.cpp`

This file matters for three reasons:

- it proves `pick-load-signs` is a real public pass name,
- it records the short public description,
- and it fixes the pass's top-level scheduler position in the ordinary optimization pipeline.

Without `pass.cpp`, it is too easy to explain the pass correctly in isolation but forget where Binaryen actually runs it.

## `src/passes/opt-utils.h`

This file does not own the pass algorithm.
It still matters because `optimizeAfterInlining(...)` can rerun the default function-optimization stack after later boundary rewrites.

That means `pick-load-signs` may appear again during nested cleanup, even though the pass itself is tiny.

This is a scheduler/placement dependency, not a semantic-pattern owner.

## Owner split in one table

| File | Ownership role | What it contributes |
| --- | --- | --- |
| `src/passes/PickLoadSigns.cpp` | core owner | Candidate discovery, usage accounting, final signedness decision, atomic skip |
| `src/ir/properties.h` | helper semantics | Exact sign/zero-extension shape recognition and width extraction |
| `src/passes/pass.cpp` | public registration and preset placement | CLI-visible pass identity plus top-level pipeline slot |
| `src/passes/opt-utils.h` | nested-rerun context | Explains why the pass can run again after inlining-related cleanup |

## What the owner map says about implementation complexity

Compared with many Binaryen optimization passes, `pick-load-signs` has a very small ownership graph.

It does **not** visibly depend on:

- `LocalGraph`,
- dominance or liveness as separate analysis APIs,
- effect-analysis files,
- branch utility layers,
- or module-wide type rewriting helpers.

That is a durable teaching point.
The pass is narrow because it mostly rewrites one exact producer/use family and outsources meaning checks to `properties.h`.

## Shipped proof surface

## `test/lit/passes/pick-load-signs_sign-ext.wast`

This is the dedicated upstream lit file for the pass.

It is intentionally tiny.
It proves two central things:

- a positive case where `i32.load8_u` can flip to `i32.load8_s` when the only use is `i32.extend8_s`,
- and a negative case where a non-recognized value use on `br_if` blocks the rewrite.

That small size is not accidental.
It matches the small semantic scope of the pass.

## `test/lit/passes/optimize-instructions-sign_ext.wast`

This file belongs to a different pass, but it still matters here.

It is the neighboring proof surface that keeps one common misunderstanding honest:

- broader i64 sign-extension cleanup exists in Binaryen,
- but it should not be attributed to `pick-load-signs` in upstream `version_129`.

So this file is part of the teaching map even though it is not part of the pass's direct owner surface.

## Test split in one table

| Test file | Why it matters for `pick-load-signs` teaching | What it proves |
| --- | --- | --- |
| `test/lit/passes/pick-load-signs_sign-ext.wast` | direct dedicated proof surface | one positive recognized sign-extension case and one negative unknown-use bailout |
| `test/lit/passes/optimize-instructions-sign_ext.wast` | neighboring boundary proof | broader sign-extension cleanup exists elsewhere, especially outside the tiny upstream `pick-load-signs` surface |

## What this means for beginners

A beginner often expects a pass named `pick-load-signs` to own most signedness cleanup for narrow integer loads.
The source map shows why that is the wrong mental model.

The better model is:

- `PickLoadSigns.cpp` owns a tiny local producer/use rewrite,
- `properties.h` owns the actual sign/zero-extension pattern recognition that constrains that rewrite,
- and the broader sign-extension story is split across neighboring passes and tests.

## Current-main freshness note

A narrow 2026-04-21 spot check found no visible drift on the most important checked surfaces:

- `src/passes/PickLoadSigns.cpp`
- `test/lit/passes/pick-load-signs_sign-ext.wast`

So `version_129` remains a good source oracle for this implementation/test map.

## Porting takeaway

If Starshine ever needs a stricter source-level re-port or refactor of this pass, this page suggests a compact checklist:

1. preserve the exact non-tee `local.set(load ...)` candidate rule in `PickLoadSigns.cpp`,
2. preserve helper-driven sign/zero-extension recognition semantics from `properties.h`,
3. keep the dedicated tiny lit proof surface in mind,
4. and do not silently absorb neighboring `optimize-instructions` sign-extension behavior into the meaning of this pass.

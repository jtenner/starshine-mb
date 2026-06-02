---
kind: concept
status: supported
last_reviewed: 2026-06-02
sources:
  - ../../../raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md
  - ../../../raw/binaryen/2026-06-02-loop-invariant-code-motion-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md
  - ../../../raw/research/0696-2026-06-02-loop-invariant-code-motion-current-main-recheck.md
  - ../../../raw/research/0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md
  - ../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-builder.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/licm.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./effects-loops-and-hoisting-rules.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Upstream implementation structure and tests for `loop-invariant-code-motion`

## Main source files

## `src/passes/LoopInvariantCodeMotion.cpp`

This is the real contract source.
It owns:

- function-parallel pass shape,
- `LazyLocalGraph` setup,
- loop discovery,
- loop effect summaries,
- unconditional loop-entry scan,
- candidate filtering,
- local-dependency checks,
- `nop` replacement,
- and pre-loop block construction.

The 2026-04-24 recheck found that this file invalidates the older temp-local teaching story.
The 2026-06-02 current-main recheck, together with the earlier 2026-04-25 bridge, found no teaching-relevant drift from that correction.
The owner file moves eligible none-result statements as whole statements; it does not synthesize fresh helper locals for arbitrary value subtrees.

Important reviewed regions:

| Region | Why it matters |
| --- | --- |
| file-level pass comment and includes | Explains LICM as moving loop-invariant code to the top of loops and notes that flattening can help expose candidates. |
| `doWalkFunction(...)` | Shows per-function `LazyLocalGraph` setup before loop walking. |
| `visitLoop(...)` | Owns the real algorithm: loop scans, effect summaries, set counts, entrance walk, safety checks, `nop` replacement, and block emission. |
| `interestingToMove(...)` | Proves the candidate surface is none-typed statements plus explicit exclusions, not arbitrary value expressions. |
| `hasGetDependingOnLoopSet(...)` | Proves local-read safety depends on local-set provenance. |

## `src/passes/pass.cpp`

This file proves two public-interface facts:

- upstream public pass name: `licm`,
- the pass is registered as a normal public Binaryen pass rather than a hidden helper mode.

This is also the main proof that the local Starshine registry name is an aliasing mismatch rather than the official upstream spelling.

## `src/passes/pass.h`

This file matters less semantically, but it confirms the normal pass integration surface and helps separate “real public pass” from “local wiki nickname.”

## Important helper headers

## `src/ir/effects.h`

This is the semantic safety backbone.
LICM depends on effect reasoning to avoid moving statements earlier when that would change global state, exception behavior, mutable state, control-flow transfer, or trap timing.

## `src/ir/find_all.h`

Used for loop and local-set discovery.
This is the clean source-level clue that LICM first works from an explicit loop body and then counts local writes before deciding what can leave.

## `src/ir/local-graph.h`

Used through `LazyLocalGraph`.
This is the local dependency proof surface: a `local.get` inside a candidate blocks motion when it depends on a `local.set` that belongs to the loop being exited.

## `src/wasm-builder.h`

Used for the final tree rewrite: create `nop` placeholders and construct the block that contains moved statements followed by the loop.
This helper is about block/nop construction here, not temp-local caching.

## What the official lit file proves

## `test/lit/passes/licm.wast`

This is the main shipped behavior surface for the pass.
It is especially valuable because it shows what upstream considers part of LICM's public contract.

The reviewed test file proves these important families:

- a simple loop-entry `drop` can move before the loop,
- nested-loop motion can expose code to an outer loop,
- calls can remain behind and block broader motion,
- stores and mutable state block motion,
- `pause` / control-transfer-like boundaries limit the entrance scan,
- moved statement slots become visible as `nop`s in expected output.

The lit file should be treated as the canonical beginner-facing oracle for the concrete emitted WAT shape.

## File responsibility map

| File | Why it matters |
| --- | --- |
| `LoopInvariantCodeMotion.cpp` | Main algorithm, legality proof, statement rewrite strategy, and source correction. |
| `pass.cpp` | Official public registration name `licm`. |
| `pass.h` | Public pass integration surface. |
| `effects.h` | Effect and trap-safety reasoning backbone. |
| `find_all.h` | Explicit loop and local-set discovery helper. |
| `local-graph.h` | Local dependency proof via `LazyLocalGraph`. |
| `wasm-builder.h` | `nop` and block-construction helper for emitted prelude shape. |
| `test/lit/passes/licm.wast` | Shipped positive/bailout public behavior surface. |

## Current-main spot check

A focused 2026-04-25 current-main / port-readiness comparison checked the main pass file, public registration surface, helper headers, builder helper, and dedicated lit file.
The 2026-06-02 current-main recheck reviewed the same surfaces again and did not surface teaching-relevant drift from the refreshed `version_129` contract.

So for the surfaces reviewed in this dossier, `version_129` remains the main oracle and the 2026-06-02 recheck, together with the earlier 2026-04-25 bridge, is the freshness source for Starshine first-slice planning.

## What is easy to misunderstand from the file list alone

## 1. LICM is not mostly about finding loops

The helper files matter, but the hard part is proving that early statement execution preserves semantics.

## 2. `Builder` does not mean temp locals here

The older dossier inferred a temp-local rewrite from the existence of a builder helper.
The reviewed source uses the builder for `nop` and block construction in the emitted prelude shape.

## 3. The interesting-candidate filter is decisive

The `none`-type gate in `interestingToMove(...)` is the key reason this is a statement mover, not arbitrary value-expression hoisting.

## 4. Local graph dependency is part of correctness

A statement that reads a local is not safe just because the read looks syntactically simple.
The pass asks whether the read depends on a loop-local set.

## Future porting checklist

Before implementing this pass in Starshine, re-check at least:

- `LoopInvariantCodeMotion.cpp`, especially `visitLoop(...)`, `interestingToMove(...)`, and `hasGetDependingOnLoopSet(...)`,
- `pass.cpp`, for the public `licm` spelling,
- `effects.h`, for the effect categories Starshine must approximate,
- `local-graph.h`, for local dependency expectations,
- `test/lit/passes/licm.wast`, for emitted shape and bailout examples.

That is the smallest review surface that still preserves the real contract.

## Sources

- [`../../../raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md)
- [`../../../raw/binaryen/2026-06-02-loop-invariant-code-motion-current-main-recheck.md`](../../../raw/binaryen/2026-06-02-loop-invariant-code-motion-current-main-recheck.md)
- [`../../../raw/research/0378-2026-04-25-loop-invariant-code-motion-port-readiness.md`](../../../raw/research/0378-2026-04-25-loop-invariant-code-motion-port-readiness.md)
- [`../../../raw/research/0696-2026-06-02-loop-invariant-code-motion-current-main-recheck.md`](../../../raw/research/0696-2026-06-02-loop-invariant-code-motion-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md`](../../../raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md)
- [`../../../raw/research/0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md`](../../../raw/research/0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md)
- [`../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md`](../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-builder.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/licm.wast>

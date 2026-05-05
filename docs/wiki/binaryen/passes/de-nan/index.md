---
kind: entity
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-de-nan-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-de-nan-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md
  - ../../../raw/research/0478-2026-05-05-de-nan-current-main-recheck.md
  - ../../../raw/research/0341-2026-04-25-de-nan-current-main-recheck.md
  - ../../../raw/research/0283-2026-04-24-de-nan-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0184-2026-04-21-de-nan-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../index.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./helper-functions-fallthrough-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../precompute/index.md
  - ../global-effects/index.md
  - ../simplify-locals/index.md
---

# `de-nan` / `denan`

## Role

- `denan` is a real public Binaryen pass.
- It is currently **unimplemented** in Starshine's active optimizer and still lives in the local **removed** registry under the alias `de-nan` in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.
- `agent-todo.md` currently has **no dedicated `de-nan` / `denan` slice**.
- Upstream `pass.cpp` describes it briefly as:
  - `instrument the wasm to convert NaNs into 0 at runtime`

That summary is accurate, but it hides the most important teaching details.

A better beginner summary is:

- Binaryen walks floating- and SIMD-typed value producers,
- replaces NaN constants with zero constants immediately,
- sanitizes float/vector parameters on function entry,
- and wraps nonconstant producers in helper calls that return the original value when it is not NaN and `0` otherwise.

## Why this pass matters

- The original no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first widened upstream-only wave are already dossier-covered, so this folder is an explicit tracker expansion for another real local registry pass.
- `denan` is a good complement to the existing optimization-heavy dossiers because it shows that Binaryen also ships **instrumentation / determinization passes**, not just speed or size optimizers.
- The local-vs-upstream naming split is real and currently undocumented elsewhere: Starshine tracks `de-nan`, while official Binaryen exposes `denan`.
- The pass is small enough to audit exactly, but subtle enough to teach several important boundaries: `local.get` skipping, result-fallthrough skipping, global-initializer legality, helper-function collision handling, and SIMD self-interference avoidance.

## Beginner summary

A good mental model is:

- if a value of type `f32`, `f64`, or `v128` might become NaN,
- Binaryen wants to stop that NaN from flowing onward,
- so it either fixes the value at compile time or routes it through a small helper function at runtime.

So this pass is best taught as:

- **runtime NaN-to-zero instrumentation**
- not ordinary optimization
- not NaN payload canonicalization
- not constant folding in the usual optimizer sense
- not a default preset slot in the current Starshine parity path

## Most important durable takeaways

- The upstream public pass name is `denan`, but the local removed registry still spells it `de-nan`.
- The pass is a `ControlFlowWalker` and reports `addsEffects() = true` because it inserts helper calls.
- It skips `local.get` deliberately to avoid self-instrumentation problems.
- It skips `Properties::isResultFallthrough(...)` nodes so it does not redundantly wrap structural shells like `block`, `if`, `loop`, `select`, or `local.set`.
- NaN constants are rewritten directly to zero constants, which is what makes global-initializer repair legal.
- Nonconstant `f32`/`f64`/`v128` producers are wrapped in helper calls.
- Non-imported functions get entry fixups for float/vector params.
- The helper functions are added after the walk so they are not instrumented themselves.
- The `v128` helper path is unusually careful: it extracts `f32x4` lanes and checks them individually instead of relying on vector equality, specifically to avoid self-interference on reruns.
- The 2026-04-24 raw primary-source manifest records the official `version_129` release provenance, the source/test URLs reviewed for this pass, and the first narrow current-`main` drift check.
- The 2026-05-05 current-main recheck confirms no teaching-relevant drift: registration, helper strategy, skip families, dedicated lit proof surface, and Starshine's removed-registry status still match the living dossier.
- The dedicated Starshine strategy page now records that current Starshine preserves `de-nan` only as a removed registry entry with explicit request rejection, category tests, no owner file, and no active backlog slice.

## What this pass sounds like versus what it actually does

What it sounds like:

- make NaNs deterministic somehow
- maybe canonicalize them to one standard NaN
- maybe fold away some weird floating expressions

What it actually is in `version_129`:

- a behavior-changing instrumentation pass that forces NaNs to become zeros
- with exact runtime helper functions for `f32`, `f64`, and optionally `v128`
- plus compile-time fixups for NaN constants and function-entry repairs for incoming float/vector params

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the real implementation structure, helper dependencies, and main rewrite phases.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./helper-functions-fallthrough-and-boundaries.md`](./helper-functions-fallthrough-and-boundaries.md)
  Focused guide to the easiest parts to misread: why `local.get` and result-fallthrough nodes are skipped, how the helper functions work, and where module-context legality stops call-based repair.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly shape catalog showing the main positive, preserved, and bailout families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and port-planning bridge: exact removed-registry / request-rejection / test code locations, no owner file, no active backlog slice, and why a faithful future port is probably module-owned instrumentation rather than an ordinary HOT peephole.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Compact validation bridge: the removed-registry hold point, exact local code map, and the shape/compare ladder a future implementation would need.

## Current maintenance rule

- Treat this folder as the canonical home for future `de-nan` / `denan` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass for it.
- Keep the split from the default optimize-path docs explicit: this is an optional instrumentation pass, not a missing no-DWARF parity slot.
- Keep the split from ordinary `precompute` or floating simplification explicit too: this pass does not try to keep NaNs around in canonical form, it erases them into zeros.

## Sources

- [`../../../raw/binaryen/2026-05-05-de-nan-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-de-nan-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md`](../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md)
- [`../../../raw/research/0478-2026-05-05-de-nan-current-main-recheck.md`](../../../raw/research/0478-2026-05-05-de-nan-current-main-recheck.md)
- [`../../../raw/research/0283-2026-04-24-de-nan-primary-sources-and-starshine-followup.md`](../../../raw/research/0283-2026-04-24-de-nan-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0184-2026-04-21-de-nan-binaryen-research.md`](../../../raw/research/0184-2026-04-21-de-nan-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)
- Binaryen `version_129` sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/DeNaN.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/properties.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/names.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/denan.wast>
- Narrow freshness-check sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/DeNaN.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/properties.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/names.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/wasm-builder.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/pass.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/denan.wast>

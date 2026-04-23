---
kind: entity
status: working
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md
  - ../../../raw/research/0182-2026-04-21-const-hoisting-binaryen-research.md
  - ../../../raw/research/0225-2026-04-21-const-hoisting-literal-identity-followup.md
  - ../../../raw/research/0276-2026-04-23-const-hoisting-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../index.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./size-model-and-boundaries.md
  - ./literal-bit-identity-zero-signs-and-nan-payloads.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../precompute/index.md
  - ../optimize-added-constants/index.md
  - ../merge-similar-functions/index.md
---

# `const-hoisting`

## Role

- `const-hoisting` is a real public Binaryen pass.
- It is currently **unimplemented** in Starshine's active optimizer and still lives in the local **removed** registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.
- `agent-todo.md` currently has **no dedicated `const-hoisting` slice**.
- Upstream `pass.cpp` describes it briefly as:
  - `hoist repeated constants to a local (necessary for the register allocator in some cases)`

That summary is technically true, but too vague.

A better beginner summary is:

- Binaryen scans one function for repeated literal constants,
- estimates whether one `local.set` plus many `local.get`s would be smaller in raw wasm bytes than repeating the literal payload inline,
- and rewrites only the profitable literal groups.

## Why this pass matters

- The original no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first widened upstream-only wave are already dossier-covered, so this folder is an explicit tracker expansion for another real local registry pass.
- `const-hoisting` is small, but it teaches an optimization idea that beginner readers often miss: **binary encoding size economics are not the same thing as runtime speed or generic constant folding**.
- It sits naturally beside already-covered size and literal-neighbor passes like `precompute*`, `optimize-added-constants*`, `simplify-locals*`, and `merge-similar-functions`, but it solves a different problem from all of them.
- The upstream implementation and tests are tiny enough to audit exactly, which makes it a good high-confidence source-backed addition.
- The folder now also has an immutable raw primary-source manifest and a dedicated Starshine status/port-strategy page, so readers no longer need to reconstruct either reviewed release provenance or the local port-planning story from older research notes alone.

## Beginner summary

A good mental model is:

- some constants are cheap to encode inline, so hoisting them would only add overhead
- some constants are expensive to encode inline, especially large signed-LEB integers and floating-point literals
- if the same expensive constant appears often enough, Binaryen creates a temp local at function entry and rewrites those uses to `local.get`

So this pass is best taught as:

- **repeated-literal size compression inside one function**
- not constant propagation
- not value numbering
- not global pooling
- not a default optimize-preset pass in the current Starshine parity path

## Most important durable takeaways

- The pass is a tiny `PostWalker` over `Const` nodes.
- Grouping is by exact `Literal` value, not by equivalent arithmetic expression.
- For float literals, that means typed bit identity: `+0.0`, `-0.0`, and distinct NaN payloads are different hoist buckets.
- Profitability is byte-based:
  - `before = num * size`
  - `after = size + 2 + 2 * num`
  - hoist only if `after < before`
- Small `1`- and `2`-byte signed-LEB constants are never worth hoisting.
- Typical thresholds are:
  - `3`-byte constants need `6` uses
  - `4`-byte constants need `4` uses
  - `8`-byte constants need `2` uses
- `v128` constants are explicitly unsupported in `version_129`.
- The pass inserts a function-entry prelude block and relies on later cleanup such as `merge-blocks` to smooth structure afterwards.
- A narrow current-`main` check found the implementation, registration, and dedicated lit file unchanged from `version_129`, so the tagged release is a reliable oracle here.

## What this pass sounds like versus what it actually does

What it sounds like:

- hoist constants into locals whenever they repeat

What it actually is in `version_129`:

- a function-local raw-binary-size pass over already-materialized literal constants
- with exact encoded-size measurement for integers and fixed byte widths for floats
- and an intentionally tiny rewrite surface: one fresh local, one prelude `local.set`, many `local.get`s

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the real implementation structure, helper dependencies, and main rewrite phases.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./size-model-and-boundaries.md`](./size-model-and-boundaries.md)
  Focused guide to the easiest part to misread: the byte-size algebra, the exact thresholds, and the deliberate non-goals.
- [`./literal-bit-identity-zero-signs-and-nan-payloads.md`](./literal-bit-identity-zero-signs-and-nan-payloads.md)
  Focused guide to the second easy-to-miss part of the pass: exact `Literal` grouping, float bit identity, `+0.0` versus `-0.0`, NaN payload buckets, and the one stale `f64` threshold comment in the upstream lit file.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly shape catalog showing the profitable literal families, the preserved small-literal families, and the main bailout surfaces.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Exact current Starshine status and port map, including the removed-registry location, runtime rejection path, the still-missing active backlog slice, and the most relevant neighboring local size-pass dossiers.

## Current maintenance rule

- Treat this folder as the canonical home for future `const-hoisting` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass for it.
- Keep the split from `precompute` explicit: `precompute` creates constants, but `const-hoisting` decides whether repeated literal payloads should be compressed through locals.
- Keep the split from generic locals optimization explicit too: this pass introduces fresh locals for size reasons, but it does not attempt broad locals cleanup or register-pressure reasoning.
- Treat the raw primary-source manifest plus the new Starshine page as the default provenance-and-navigation pair for future `const-hoisting` follow-ups.

## Sources

- [`../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md`](../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md)
- [`../../../raw/research/0182-2026-04-21-const-hoisting-binaryen-research.md`](../../../raw/research/0182-2026-04-21-const-hoisting-binaryen-research.md)
- [`../../../raw/research/0225-2026-04-21-const-hoisting-literal-identity-followup.md`](../../../raw/research/0225-2026-04-21-const-hoisting-literal-identity-followup.md)
- [`../../../raw/research/0276-2026-04-23-const-hoisting-primary-sources-and-starshine-followup.md`](../../../raw/research/0276-2026-04-23-const-hoisting-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)

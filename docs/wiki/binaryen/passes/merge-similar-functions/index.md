---
kind: entity
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-merge-similar-functions-current-main-recheck.md
  - ../../../raw/research/0443-2026-05-05-merge-similar-functions-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md
  - ../../../raw/research/0332-2026-04-25-merge-similar-functions-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0174-2026-04-21-merge-similar-functions-binaryen-research.md
  - ../../../raw/research/0201-2026-04-21-merge-similar-functions-mechanics-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./equivalence-classes-param-derivation-and-thunk-rewrites.md
  - ./profitability-indirection-and-type-barriers.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../tracker.md
---

# `merge-similar-functions`

## Role

- `merge-similar-functions` is a real public Binaryen pass.
- It is currently **unimplemented** in Starshine's active optimizer and still lives in the local **removed** registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is also still listed in the local Batch 4 registry map in [`../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.
- Official Binaryen instead schedules it in the late global post-pass phase when **`shrinkLevel >= 2`**, placing it near size-focused neighbors like `duplicate-function-elimination`, `duplicate-import-elimination`, and `simplify-globals*`.

## Why this pass matters

- The original no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first widened upstream-only registry wave are already dossier-covered, so this folder is an explicit source-backed expansion for another real local removed-registry entry.
- `agent-todo.md` currently has **no dedicated `merge-similar-functions` slice**.
- The pass sits directly beside already-documented late module neighbors, but it solves a different problem from `duplicate-function-elimination`: it merges **near-duplicates by inventing parameters and thunks**, not exact duplicates.
- It is relevant to future `-Oz` / `-O4z` / shrink-family parity work even though it is outside the current no-DWARF `-O` / `-Os` page.

## Why this follow-up still mattered

This folder was already stronger than a bare landing page, but it still had one major teaching gap:

- it explained the pass well at a high level,
- but it did not yet isolate the **exact mechanics** of class formation, diff-vector reuse, helper cloning, local-index shifting, and thunk replacement in one source-confirmed page.

That gap mattered because a future port can easily go wrong by:

- confusing same-hash with same-equivalence-class,
- deriving one synthetic param per differing node instead of reusing exact diff-vectors,
- forgetting that call-target parameterization is feature-gated,
- or forgetting to shift old non-param locals upward after appending synthetic params.

This refreshed dossier now closes that mechanics gap.

The 2026-05-05 refresh closes the remaining provenance and local-status gap: the folder now has an immutable current-main bridge, a dedicated Starshine strategy page, and a port-readiness / validation bridge that maps the removed-name registry to exact local code locations.

## Beginner summary

A good beginner mental model is:

- several functions do almost the same thing
- the only differences are some constant values or, in some feature-gated cases, which same-signature direct callee they call
- Binaryen makes one shared helper function
- that helper receives the differing pieces as extra parameters
- each old function becomes a tiny thunk that forwards its original params plus its own payloads

So this pass is best taught as:

- **whole-module parameterization of near-duplicate functions for code size**
- not duplicate-function elimination
- not inlining
- not generic outlining

## Most important durable takeaways

- The reviewed implementation is a late whole-module size pass.
- The matching surface is narrow: it allows differences in `const` immediates and, with reference types + GC, some direct `call` targets.
- The pass uses a two-stage pipeline: coarse hash grouping first, then exact structural comparison with a custom equality relation.
- Same hash is **not** the same thing as a real equivalence class.
- Parameter derivation is a lockstep DFS over the primary body and sibling bodies, not a generic post-hoc constant scan.
- Repeated identical diff-vectors reuse one synthetic parameter instead of creating one param per occurrence.
- The merged helper is cloned from one primary function and original functions become thunks.
- Helper construction must shift the original non-param locals upward after synthetic params are appended.
- Call-target parameterization uses `ref.func` thunk payloads plus `call_ref` / `return_call_ref` in the shared helper.
- Profitability and the `255` synthetic-param limit are first-class bailout rules, not mere polish.
- A 2026-05-05 current-main recheck found the same implementation file contents as `version_129` on the reviewed surface.
- Starshine currently keeps the pass as a removed-registry known name: explicit requests are rejected before execution, no module owner file exists, and no active backlog slice is open.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen implementation, algorithmic phases, helper dependencies, scheduler placement, and pass interactions.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./equivalence-classes-param-derivation-and-thunk-rewrites.md`](./equivalence-classes-param-derivation-and-thunk-rewrites.md)
  Source-confirmed mechanics page for the real heart of the pass: same-hash versus same-class, lockstep `DeepValueIterator` param derivation, exact diff-vector reuse, helper cloning with local-index shifting, and original-name-preserving thunk replacement.
- [`./profitability-indirection-and-type-barriers.md`](./profitability-indirection-and-type-barriers.md)
  Focused guide to the easiest-to-misread half of the pass: when Binaryen may parameterize call targets, when type relations still block it, and why tiny or over-wide merges are rejected.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly shape catalog showing the main positive, mixed, and bailout WAT families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future-port map: removed-registry entry, request rejection, no owner/dispatcher/preset/backlog state, reusable module representation surfaces, and the module-level helper/thunk rewrite phases a faithful port would need.

## Current maintenance rule

- Treat this folder as the canonical home for future `merge-similar-functions` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real late module pass for it.
- Keep the scheduler fact explicit too: this is a real public Binaryen pass, but it belongs to the shrink-family late global post-pass story, not the repo's current no-DWARF `-O` / `-Os` path.
- Keep the split from `duplicate-function-elimination` explicit too: exact duplicates belong to DFE, near-duplicates-with-synthetic-params belong here.
- Keep the mechanics fact explicit too: the real contract is not just “helper plus thunks,” but a source-backed hash-then-classify-then-diff-derive-then-clone-and-shift-locals algorithm.
- Keep the Starshine status explicit too: the local codebase currently tracks this only as a removed registry name, not as a scheduled module pass.

## Sources

- [`../../../raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md`](../../../raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md)
- [`../../../raw/research/0332-2026-04-25-merge-similar-functions-primary-sources-and-starshine-followup.md`](../../../raw/research/0332-2026-04-25-merge-similar-functions-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0174-2026-04-21-merge-similar-functions-binaryen-research.md`](../../../raw/research/0174-2026-04-21-merge-similar-functions-binaryen-research.md)
- [`../../../raw/research/0201-2026-04-21-merge-similar-functions-mechanics-followup.md`](../../../raw/research/0201-2026-04-21-merge-similar-functions-mechanics-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` and current-main sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeSimilarFunctions.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/hashed.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-limits.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_all-features.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_types.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions-param-limit.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeSimilarFunctions.cpp>

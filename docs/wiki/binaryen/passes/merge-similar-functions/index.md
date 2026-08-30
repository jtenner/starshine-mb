---
kind: entity
status: supported
last_reviewed: 2026-08-29
sources:
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../../ir2/registry-map.md
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

- `merge-similar-functions` is a real public Binaryen pass and an active Starshine module pass.
- Starshine's owner is [`src/passes/merge_similar_functions.mbt`](../../../../../src/passes/merge_similar_functions.mbt); the public registry and dispatcher accept `--merge-similar-functions`.
- It remains outside the wall-time-first non-O4z presets.
- Binaryen schedules it in the late global post-pass phase when **`shrinkLevel >= 2`**. Starshine preserves the locked O4z top-level queue and runs generic MSF through the existing validated `optimized-similar-functions` portfolio candidate.

## Why this pass matters

- The pass closes the previously measured 117,057-byte O4z size gap owner without disturbing the locked scheduler.
- The integrated O4z artifact is 5,113,549 bytes versus pinned Binaryen 131 at 5,144,062 bytes on the same 14,943,550-byte input.
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
- Starshine implements the complete helper/thunk path, validates every candidate transactionally, and owns eight dedicated GenValid leaves.

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
  Current active implementation, safety boundaries, O4z portfolio integration, performance, and artifact result.

## Current maintenance rule

- Treat this folder as the canonical home for `merge-similar-functions` implementation and signoff evidence.
- Keep the active module-pass status, eight-leaf GenValid aggregate, and O4z portfolio integration synchronized with source.
- Keep the scheduler distinction explicit: Binaryen owns a shrink-level late-global slot, while Starshine preserves its locked top-level queue and selects the validated MSF portfolio candidate.
- Keep the split from `duplicate-function-elimination` explicit too: exact duplicates belong to DFE, near-duplicates-with-synthetic-params belong here.
- Keep the mechanics fact explicit too: the real contract is not just “helper plus thunks,” but a source-backed hash-then-classify-then-diff-derive-then-clone-and-shift-locals algorithm.
- Keep the Starshine status explicit too: the local codebase currently tracks this only as a removed registry name, not as a scheduled module pass.

## Sources

- research note 0332
- research note 0174
- research note 0201
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [research note 0063](../../../ir2/registry-map.md)
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

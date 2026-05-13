---
kind: entity
status: supported
last_reviewed: 2026-05-13
sources:
  - ../../../raw/research/0524-2026-05-06-duplicate-function-elimination-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-13-duplicate-function-elimination-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-duplicate-function-elimination-validation-primary-sources.md
  - ../../../raw/research/0425-2026-04-27-duplicate-function-elimination-validation-bridge.md
  - ../../../raw/binaryen/2026-04-26-duplicate-function-elimination-current-main-and-starshine-strategy-health.md
  - ../../../raw/research/0399-2026-04-26-duplicate-function-elimination-strategy-health.md
  - ../../../raw/binaryen/2026-04-22-duplicate-function-elimination-primary-sources.md
  - ../../../raw/research/0242-2026-04-22-duplicate-function-elimination-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0147-2026-04-20-duplicate-function-elimination-binaryen-research.md
  - ../../../raw/research/0067-2026-03-24-duplicate-function-elimination.md
  - ../../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../../src/passes/duplicate_function_elimination_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DuplicateFunctionElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/function-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/hashed.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_annotations.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_branch-hints.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_optimize-level=1.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_optimize-level=2.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/DuplicateFunctionElimination.cpp
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./scheduler-validation-and-parity.md
  - ./type-compaction-and-metadata.md
  - ./parity.md
  - ../../../binary/function-import-export-and-code-sections.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `duplicate-function-elimination`

## Role

- `duplicate-function-elimination` is an active implemented **module pass** in Starshine.
- In upstream Binaryen `version_129`, the public `pass.cpp` description is only:
  - `removes duplicate functions`

That description is accurate, but it is easy to read too broadly.

A better beginner summary is:

- Binaryen hashes defined functions,
- exact-compares only the functions that land in the same hash bucket,
- keeps the earliest equal function as the survivor,
- rewrites function references to that survivor,
- and may repeat the process when optimization settings allow newly-rewritten callers to become equal too.

So this is **not** a general type-compaction pass and **not** a generic metadata cleanup pass.
It is a small whole-module duplicate-function identity pass.

## Why this pass matters

- In the canonical no-DWARF `-O` / `-Os` scheduler, Binaryen runs DFE twice:
  - once at the start of global pre-passes
  - and once again in global post-passes after DAE / inlining may have created new duplicates
- That placement is meaningful:
  - the early run is cheap and can save work for everything that follows
  - the late run catches duplication that bigger transforms expose later
- The pass is source-important even though the official file is small.
  - getting the equality contract or iteration budget wrong changes which functions survive
  - getting the rewrite surface wrong leaves stale function references behind

## Most important durable takeaways

- Upstream Binaryen `version_129` DFE is **narrower** than the current local MoonBit pass.
- The real official contract is:
  - hash candidates
  - exact-compare within buckets
  - remove later duplicates
  - rewrite function references
  - iterate according to optimize/shrink settings
- Imported functions are never DFE candidates in the real pass because it buckets only **defined** functions.
- Non-semantic metadata differences like branch hints and debug locations do **not** block merging.
- Semantics-altering function annotations do block merging unless they match.
- Current Starshine type compaction, name stripping, element canonicalization, and annotation-map rewriting are local extras, not the upstream DFE algorithm itself.
- The shared imported-prefix `FuncIdx` model that DFE must preserve while rewriting references is summarized in [`../../../binary/function-import-export-and-code-sections.md`](../../../binary/function-import-export-and-code-sections.md).

## Biggest beginner correction

The easy wrong mental model is:

- “Binaryen DFE merges duplicate functions and then also compacts duplicate types, rewrites lots of type-index users, strips names, and normalizes metadata.”

The safer source-backed mental model is:

- Binaryen DFE is just the duplicate-function identity loop.
- If the local Starshine implementation does more, that extra work should be documented as **Starshine-local cleanup layered around DFE**, not silently attributed to official Binaryen.

That distinction is the main reason this folder needed a 2026-04-20 refresh and a narrower 2026-04-22 provenance/code-map follow-up even though it already had multiple pages.

## What the pass sounds like versus what it actually does

What it sounds like:

- remove identical functions

What it actually is in `version_129`:

- a module pass with an option-dependent iteration budget,
- a parallel hash prefilter,
- an exact equality check that ignores non-semantic metadata but honors semantics-altering annotations,
- stable first-survivor-wins selection inside each bucket,
- and a whole-module function-reference rewrite helper.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the real `DuplicateFunctionElimination.cpp` structure, scheduler placement, helper dependencies, and option-dependent iteration rules.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Upstream file map and official test map: what `function-utils.h`, `hashed.h`, and `opt-utils.h` each contribute, and what the dedicated lit files prove.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering positive merge families, ref.func/global/export/start rewrites, iteration-driven transitive unlocks, and the main non-merge families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Current in-tree Starshine strategy with the exact MoonBit registry/dispatcher/core-rewrite code map, plus the explicit reason this remains a module pass rather than a HOT pass. The 2026-04-26 health pass renamed this page from the stale `starshine-hot-ir-strategy.md` filename.
- [`./scheduler-validation-and-parity.md`](./scheduler-validation-and-parity.md)
  - Read-along validation bridge tying together upstream repeat-budget and two-slot scheduling, current Starshine one-iteration explicit-pass behavior, local extra cleanup, focused test surfaces, and the evidence required before public preset scheduling.
- [`./type-compaction-and-metadata.md`](./type-compaction-and-metadata.md)
  - The crucial source-backed distinction between upstream DFE proper and the broader local type/name/metadata cleanup currently bundled into Starshine's pass, now with concrete local before/after shape families and exact owner-file locations.
- [`./parity.md`](./parity.md)
  - Current parity framing, including the now-explicit split between upstream DFE behavior and local extra cleanup work.

## Freshness note

Narrow 2026-04-20, 2026-04-26, 2026-04-27, 2026-05-04, and 2026-05-13 checks found **no semantic post-`version_129` drift** on the dedicated DFE surface.

- All five `duplicate-function-elimination*` lit files are identical on current `main` and `version_129`.
- The 2026-05-13 current-main recheck kept that result unchanged.
- The core pass file differs only by a tiny non-semantic container change:
  - `std::set<Name>` -> `std::unordered_set<Name>` for the duplicate-name set.

So the durable rule is:

- treat Binaryen `version_129` as the released algorithm oracle for this dossier
- keep the current-main note explicit only to say that the checked core logic and tests still match semantically
- use the raw primary-source manifest when future follow-ups need exact release/source/test provenance without re-deriving it from the living pages

## 2026-05-06 direct revalidation

The post-fuzzer-change direct signoff lane is green for the explicit pass surface:

- `moon info`, `moon fmt`, and `moon test` passed.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass duplicate-function-elimination --out-dir .tmp/pass-fuzz-duplicate-function-elimination` compared `6759 / 10000` cases with `6759` normalized matches, `0` mismatches, and `20` Binaryen empty-recursion-group parser/canonicalization command failures.

This refresh removes `duplicate-function-elimination` from the AUD002 direct-pass revalidation queue. It does not close the separate preset-scheduler / multi-iteration Binaryen gap.

## Current maintenance rule

- Treat this folder as the canonical home for future DFE parity and scheduler research.
- Keep the main beginner correction explicit:
  - upstream `duplicate-function-elimination` is a small duplicate-function identity pass, not the whole local type/name cleanup bundle
- When future work changes local DFE behavior, update the folder in the right place:
  - upstream contract changes go in `binaryen-strategy.md` or `implementation-structure-and-tests.md`
  - scheduler, iteration, and validation decisions go in `scheduler-validation-and-parity.md`
  - local extra cleanup changes go in `type-compaction-and-metadata.md`, `starshine-strategy.md`, or `parity.md`

## Sources

- [`../../../raw/research/0524-2026-05-06-duplicate-function-elimination-direct-revalidation.md`](../../../raw/research/0524-2026-05-06-duplicate-function-elimination-direct-revalidation.md)
- [`../../../raw/binaryen/2026-04-27-duplicate-function-elimination-validation-primary-sources.md`](../../../raw/binaryen/2026-04-27-duplicate-function-elimination-validation-primary-sources.md)
- [`../../../raw/research/0425-2026-04-27-duplicate-function-elimination-validation-bridge.md`](../../../raw/research/0425-2026-04-27-duplicate-function-elimination-validation-bridge.md)
- [`../../../raw/binaryen/2026-04-26-duplicate-function-elimination-current-main-and-starshine-strategy-health.md`](../../../raw/binaryen/2026-04-26-duplicate-function-elimination-current-main-and-starshine-strategy-health.md)
- [`../../../raw/binaryen/2026-05-13-duplicate-function-elimination-current-main-recheck.md`](../../../raw/binaryen/2026-05-13-duplicate-function-elimination-current-main-recheck.md)
- [`../../../raw/research/0399-2026-04-26-duplicate-function-elimination-strategy-health.md`](../../../raw/research/0399-2026-04-26-duplicate-function-elimination-strategy-health.md)
- [`../../../raw/binaryen/2026-04-22-duplicate-function-elimination-primary-sources.md`](../../../raw/binaryen/2026-04-22-duplicate-function-elimination-primary-sources.md)
- [`../../../raw/research/0242-2026-04-22-duplicate-function-elimination-primary-sources-and-code-map-followup.md`](../../../raw/research/0242-2026-04-22-duplicate-function-elimination-primary-sources-and-code-map-followup.md)
- [`../../../raw/research/0147-2026-04-20-duplicate-function-elimination-binaryen-research.md`](../../../raw/research/0147-2026-04-20-duplicate-function-elimination-binaryen-research.md)
- [`../../../../../src/passes/duplicate_function_elimination.mbt`](../../../../../src/passes/duplicate_function_elimination.mbt)
- [`../../../../../src/passes/duplicate_function_elimination_test.mbt`](../../../../../src/passes/duplicate_function_elimination_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DuplicateFunctionElimination.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/function-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/hashed.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_all-features.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_annotations.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_branch-hints.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_optimize-level=1.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_optimize-level=2.wast>
- Narrow freshness-check surface:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DuplicateFunctionElimination.cpp>
